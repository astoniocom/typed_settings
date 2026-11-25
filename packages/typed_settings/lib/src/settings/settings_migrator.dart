import 'dart:async';

import 'package:meta/meta.dart';
import 'package:typed_settings/src/diagnostics/settings_persist_exception.dart';
import 'package:typed_settings/src/settings/settings_registry.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';

/// One step that brings a storage's layout to [toVersion].
///
/// [apply] runs against the storage itself, below any setting, and may
/// rename keys, change representations, split or drop values. It may be
/// asynchronous, for example to read an external source the values are
/// moved from. Reads of the storage are synchronous; its writes are queued
/// and the migrator flushes them before recording the version.
///
/// A step must be idempotent: the migrator records the new version only
/// after the step's writes have been persisted, so if the application is
/// killed in between, or a write does not persist, the step runs again on
/// the next start over its own partial result. Write steps so that absent
/// keys and already-migrated values are a no-op.
///
/// A step that moves a value (writes it under a new key and removes the
/// old one) writes first, awaits `storage.flush()` and only then removes
/// the old key: the flush fails when the write did not persist, which
/// stops the step before the removal, so the next run still finds the
/// value under the old key.
@immutable
final class SettingsMigration<S extends SettingsStorage> {
  /// Creates the step that brings a storage to [toVersion] by running
  /// [apply]; [toVersion] must be positive, which [SettingsMigrator]
  /// checks.
  const SettingsMigration(
    this.toVersion,
    this.apply,
  );

  /// Layout version the storage has after [apply].
  final int toVersion;

  /// Transforms the storage's layout; see the class documentation for
  /// what it may do and the idempotency requirement.
  final FutureOr<void> Function(S storage) apply;
}

/// Applies the [SettingsMigration]s a storage has not seen yet, in order,
/// and records the resulting layout version in the storage itself.
///
/// Run it once at startup, before any setting backed by the storage is
/// read, so that settings see the migrated layout from the first read
/// (a setting created earlier picks the changes up through its key
/// listener, at the cost of a notification per migrated key). A storage
/// without a recorded version is at version 0, so every
/// migration runs against it; write migrations so that absent keys are a
/// no-op and a fresh install stays cheap.
///
/// The version lives under [versionKey] in the migrated storage's own key
/// space, so it is scoped per box and `clear()` removes it along with the
/// data. That is consistent: an emptied storage is at version 0, holds
/// nothing to migrate, and migrations are no-ops on absent keys. Being a
/// key of the storage, it is listed by `SettingsStorage.keys`; code that
/// exports the keys skips [versionKey].
///
/// Each migrator names its [versionKey]: a module of the application owns
/// one, so that modules sharing a storage each keep their own version and
/// one never takes the other's steps for done. Keep the name for the life
/// of the application; another name is another version, at 0.
///
/// For a mere key rename, `legacyKeys` on the keyed slot is simpler. For a
/// renamed enum constant, use `legacyNames`.
final class SettingsMigrator<S extends SettingsStorage> {
  /// Creates a migrator for [migrations], whose `toVersion`s must be
  /// positive and strictly ascending; an [ArgumentError] reports them
  /// otherwise, since [run] would skip a step or record a lower version
  /// after a higher one. The recorded version lives under [versionKey].
  SettingsMigrator(this.migrations, {required this.versionKey}) {
    var previous = 0;
    for (final migration in migrations) {
      if (migration.toVersion <= previous) {
        throw ArgumentError(
          'migrations must have positive, strictly ascending toVersion; '
          '${migration.toVersion} follows $previous',
        );
      }
      previous = migration.toVersion;
    }
  }

  /// The steps, in ascending `toVersion` order.
  final List<SettingsMigration<S>> migrations;

  /// Key under which the current layout version is recorded, in the
  /// migrated storage's own key space (so it is scoped per box).
  final String versionKey;

  /// The layout version the migrations bring a storage to; 0 when empty.
  int get latestVersion => migrations.isEmpty ? 0 : migrations.last.toVersion;

  /// The recorded layout version of [storage]; 0 when none is recorded.
  int currentVersion(S storage) => storage.getInt(versionKey) ?? 0;

  /// Runs every migration with `toVersion` above the recorded version and
  /// returns the number of migrations applied.
  ///
  /// A step counts as applied once both its data and its version are
  /// persisted: the storage is flushed after the step, then the version is
  /// recorded and flushed in turn. The persisted version therefore never
  /// runs ahead of the persisted data: a kill at any point leaves either
  /// the old version with partial data (the step re-runs; see the
  /// idempotency requirement) or the new version with complete data.
  ///
  /// The run stops at the first step that throws, with the step's error,
  /// and at the first flush that fails, with its
  /// [SettingsPersistException]; the persisted version stays at the last
  /// step applied. A flush fails for every key that is out of date,
  /// including ones written before the run: no step builds on a storage
  /// that does not persist. Writes a step made before it threw keep
  /// persisting in the background; their failures are reported to the
  /// storage's observer.
  ///
  /// A recorded version above [latestVersion] means a newer release of the
  /// application wrote the data, in a layout this one does not know: the
  /// run throws a [SettingsDowngradeException] before any step, and the
  /// application decides whether to reset the storage or refuse to start.
  ///
  /// [versionKey] is kept off settings from the first run on (a setting
  /// over it, or listing it as a legacy key, is a [StateError]), and the
  /// run throws a [StateError] when a live setting already uses it. Runs
  /// over one storage take turns: a run started while another is going
  /// waits for it, then reads the version it recorded.
  Future<int> run(S storage) async {
    SettingsRegistry.reserve(storage, versionKey, purpose: 'the layout version of a SettingsMigrator');
    final previous = _runs[storage];
    final done = Completer<void>();
    _runs[storage] = done.future;
    try {
      if (previous != null) await previous;
      return await _migrate(storage);
    } finally {
      done.complete();
      if (identical(_runs[storage], done.future)) _runs[storage] = null;
    }
  }

  /// The end of the latest run over each storage, so that the next one
  /// starts after it.
  static final Expando<Future<void>> _runs = Expando('typed_settings: migration runs');

  Future<int> _migrate(S storage) async {
    final from = currentVersion(storage);
    if (from > latestVersion) {
      throw SettingsDowngradeException(recordedVersion: from, latestVersion: latestVersion);
    }
    if (from > 0) await _persistVersion(storage, from);
    var applied = 0;
    for (final migration in migrations) {
      if (migration.toVersion <= from) continue;
      await migration.apply(storage);
      await storage.flush();
      storage.setInt(versionKey, migration.toVersion);
      await storage.flush();
      applied++;
    }
    return applied;
  }

  /// Makes sure [version], what [storage] reads as its version, is also
  /// what its backend holds. A run whose last flush failed leaves the
  /// version in memory only, and a later run in the same process would
  /// otherwise take the step for done while the backend still holds the
  /// version before it: the version is written again, and a flush that
  /// fails again fails the run.
  Future<void> _persistVersion(S storage, int version) async {
    try {
      await storage.flush(keys: [versionKey]);
    } on SettingsPersistException {
      storage.setInt(versionKey, version);
      await storage.flush(keys: [versionKey]);
    }
  }
}

/// A storage records a layout version above the latest one the
/// application migrates to: a newer release wrote it, and this one may
/// read it wrongly. Thrown by [SettingsMigrator.run] before any step runs.
final class SettingsDowngradeException implements Exception {
  /// The exception for [recordedVersion] found where at most
  /// [latestVersion] is known.
  const SettingsDowngradeException({required this.recordedVersion, required this.latestVersion});

  /// The version the storage records.
  final int recordedVersion;

  /// The latest version the migrations of this release bring a storage to.
  final int latestVersion;

  @override
  String toString() =>
      'SettingsDowngradeException: the storage is at layout version $recordedVersion, '
      'newer than $latestVersion, the latest this release knows';
}
