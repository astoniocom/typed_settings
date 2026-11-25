import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:typed_settings/src/diagnostics/settings_event.dart';
import 'package:typed_settings/src/diagnostics/settings_persist_exception.dart';
import 'package:typed_settings/src/storage_kit/pending_operations.dart';

/// What an operation handed to [BackgroundPersistence] brings up to date
/// in the backend: one key, several keys together, or every key. Keys are
/// persistence keys (see [BackgroundPersistence.persistenceKey]).
@immutable
sealed class PersistTarget {
  /// The key [key]. Operations scheduled with
  /// [BackgroundPersistence.persist] are ordered per key, and one still
  /// queued is replaced by a later one of the same key.
  const factory PersistTarget.key(String key) = _KeyTarget;

  /// [keys] together, as the backend side of `SettingsStorage.batch`.
  /// A scheduled operation runs after every operation over one of [keys]
  /// handed over before it and before any handed over after it, so an
  /// older write of one of its keys cannot overtake it. A failure is
  /// reported as one [PersistErrorEvent] per key and leaves each of them
  /// out of date.
  factory PersistTarget.keys(Iterable<String> keys) = _KeysTarget;

  /// Every key: the operation brings the backend state of every key in
  /// line with the in-memory state, as deleting the whole box after the
  /// cache was cleared does. When it succeeds, no key is out of date any
  /// more because of a failure before it. Runs after every operation
  /// handed over before it and before any handed over after it. [label]
  /// names the operation in a [PersistErrorEvent], typically the
  /// box.
  const factory PersistTarget.all(String label) = _AllTarget;
}

final class _KeyTarget implements PersistTarget {
  const _KeyTarget(this.key);

  final String key;
}

final class _KeysTarget implements PersistTarget {
  _KeysTarget(Iterable<String> keys) : keys = List.unmodifiable(keys);

  final List<String> keys;
}

final class _AllTarget implements PersistTarget {
  const _AllTarget(this.label);

  final String label;
}

/// Background-persistence bookkeeping for storages that update their
/// in-memory state synchronously and write through asynchronously.
///
/// A storage owns one and delegates `SettingsStorage.flush` to its
/// [flush]. It provides [flush] and the reporting of failures (to
/// [report], typically the storage's observer), over one of two ways to
/// hand an operation to the queue; which one a backend uses follows from
/// who owns the in-memory state:
///
/// * [persist] when the storage owns it (a cache it updated itself, as
///   `StringBackedStorage` does) and the backend write is a detached
///   operation. The queue runs it later: in order with the operations
///   over its keys, and alongside those over other keys up to
///   [maxConcurrentOperations] at once.
/// * [track] when the backend updates its own in-memory state inside the
///   call (Hive) and orders its writes itself. The storage makes the call
///   right away, so the mutation contract holds even while an earlier
///   write of the same key is still in flight, and only hands the future
///   over.
///
/// Either takes a [PersistTarget]: what the operation brings up to date.
///
/// A key whose persistence failed is out of date until a later operation
/// persists it: a successful one of the same key, or a successful one
/// over every key ([PersistTarget.all]). [flush] fails for out-of-date
/// keys (see `SettingsStorage.flush`). This relies on the operations of
/// one key finishing in the order they were handed over, which the queue
/// guarantees for [persist] and a backend using [track] guarantees by
/// ordering its writes. A backend that hands keys over in its own key
/// space (with a box prefix) passes a [persistenceKey], so that a flush
/// scoped to setting keys finds them.
///
/// [persistenceDelay] holds each single-key [persist] and keeps only the
/// latest action for that key, until the duration has passed without a
/// newer one. The storage updates its in-memory state before [persist],
/// so a read does not wait. [flush] and [pendingOperationsSettled] start
/// a held write instead of waiting the duration out. A write of several
/// keys, a barrier and [track] are not held: the backend call has
/// already been made, or the operation is the one burst of a `batch` or
/// a `clear`. An [ArgumentError] when [persistenceDelay] is zero or
/// negative.
final class BackgroundPersistence {
  /// An [ArgumentError] when [maxConcurrentOperations] is below one, or
  /// when [persistenceDelay] is zero or negative.
  BackgroundPersistence({
    required this.report,
    this.persistenceKey = _sameKey,
    this.maxConcurrentOperations = 1,
    Duration? persistenceDelay,
  }) : persistenceDelay = _checkDelay(persistenceDelay),
       _pending = PendingOperations(maxConcurrent: maxConcurrentOperations);

  static Duration? _checkDelay(Duration? delay) {
    if (delay != null && delay <= Duration.zero) {
      throw ArgumentError.value(delay, 'persistenceDelay', 'must be positive');
    }
    return delay;
  }

  static String _sameKey(String key) => key;

  /// Receives every failure as it happens; a storage passes its
  /// observer's `report`.
  final void Function(PersistErrorEvent event) report;

  /// The key under which the storage hands the persistence of a setting
  /// key to [persist] and [track]; [flush] maps its `keys` through it.
  /// Identity by default; a backend that hands over resolved keys (scoped
  /// by a box prefix) passes the mapping to the resolved key.
  final String Function(String key) persistenceKey;

  /// How many operations of [persist] over distinct keys may run at once,
  /// so that a slow write of one key does not hold the others back. One by
  /// default, which runs them one at a time in the order handed over;
  /// raise it for a backend that handles concurrent calls.
  final int maxConcurrentOperations;

  /// How long a single-key [persist] waits for a newer write of that key
  /// to replace it, or null when every write is handed over in the call.
  final Duration? persistenceDelay;

  final PendingOperations _pending;

  /// The earliest failure of each out-of-date key that nothing has
  /// persisted since, by the key its operation was handed over with.
  final Map<String, _Failure> _failures = {};

  /// The number of the latest successful operation of each key, by the key
  /// its operation was handed over with, since the earliest of
  /// [_bulkFailures]: a key persisted after a failed bulk operation is up
  /// to date again. Empty while no bulk operation has failed, which is when
  /// nothing reads it, so that it does not grow with every key ever written.
  final Map<String, int> _persistedAt = {};

  /// The failures of bulk operations over every key that no successful one
  /// has followed, in order.
  final List<_Failure> _bulkFailures = [];

  /// Schedules the asynchronous [action] that persists [target]; see
  /// [PersistTarget] for how it is ordered against other operations.
  ///
  /// [action] runs later, so it cannot be what updates the in-memory
  /// state: update that first, then schedule the backend part (as
  /// `StringBackedStorage.clearAtOnce` does). Failures are
  /// reported as [PersistErrorEvent]s, never thrown, and leave [target]
  /// out of date.
  void persist(PersistTarget target, Future<void> Function() action) {
    final settled = _settlerOf(target);
    switch (target) {
      case _KeyTarget(:final key):
        _pending.enqueue(key, action, settled, delay: persistenceDelay);
      case _KeysTarget(:final keys):
        _pending.enqueueKeys(keys, action, settled);
      case _AllTarget():
        _pending.enqueueBarrier(action, settled);
    }
  }

  /// Registers [future], the already started persistence of [target], for
  /// [flush] and error reporting. Nothing is deferred and nothing is
  /// replaced: the backend orders its operations itself, a bulk one after
  /// the writes issued before it. See the class documentation for when to
  /// use this instead of [persist].
  void track(PersistTarget target, Future<void> future) {
    final keys = switch (target) {
      _KeyTarget(:final key) => [key],
      _KeysTarget(:final keys) => keys,
      _AllTarget() => null,
    };
    _pending.track(future, _settlerOf(target), keys: keys);
  }

  OperationSettled _settlerOf(PersistTarget target) => switch (target) {
    _KeyTarget(:final key) => (sequence, failure) => _settle(key, sequence, failure),
    _KeysTarget(:final keys) => (sequence, failure) {
      for (final key in keys) {
        _settle(key, sequence, failure);
      }
    },
    _AllTarget(:final label) => (sequence, failure) => _settleAll(label, sequence, failure),
  };

  void _settle(String key, int sequence, OperationFailure? failure) {
    if (failure == null) {
      _failures.remove(key);
      if (_bulkFailures.isNotEmpty) _persistedAt[key] = sequence;
      return;
    }
    final event = PersistErrorEvent(
      key: key,
      error: failure.error,
      stackTrace: failure.stackTrace,
    );
    _failures.putIfAbsent(key, () => (sequence: sequence, event: event));
    report(event);
  }

  /// Settles a bulk operation over every key, reported under [key].
  void _settleAll(String key, int sequence, OperationFailure? failure) {
    if (failure == null) {
      _failures.removeWhere((_, failed) => failed.sequence < sequence);
      _bulkFailures.removeWhere((failed) => failed.sequence < sequence);
      if (_bulkFailures.isEmpty) _persistedAt.clear();
      return;
    }
    final event = PersistErrorEvent(key: key, error: failure.error, stackTrace: failure.stackTrace);
    _bulkFailures.add((sequence: sequence, event: event));
    report(event);
  }

  /// Completes when every operation handed over before this call has
  /// finished, whether it persisted or failed: what a `reload` waits for
  /// before it reads the backend, so that the backend holds the writes
  /// issued so far. Unlike [flush] it never fails; a failure was reported
  /// when it happened.
  Future<void> pendingOperationsSettled() => _pending.wait();

  /// Records that a `reload` made the in-memory state of every key what
  /// the backend holds, so that no key is out of date because of an
  /// earlier failure: [flush] stops failing for them. The keys of
  /// [except] (persistence keys, see [persistenceKey]) were written while
  /// the backend was read and keep their own outcome.
  void markReloaded({Set<String> except = const {}}) {
    _failures.removeWhere((key, _) => !except.contains(key));
    _bulkFailures.clear();
    _persistedAt.clear();
  }

  /// Waits for the operations handed over before this call (with [keys],
  /// those over one of them or over every key), then fails with a
  /// [SettingsPersistException] for the keys (all of them, or those of
  /// [keys]) that one of those operations left out of date; see
  /// `SettingsStorage.flush`.
  Future<void> flush({Iterable<String>? keys}) async {
    final issuedBefore = _pending.nextSequence;
    await _pending.wait(keys: keys?.map(persistenceKey));
    final failures = keys == null ? _allFailuresBefore(issuedBefore) : _failuresBefore(issuedBefore, keys);
    if (failures.isNotEmpty) throw SettingsPersistException(failures);
  }

  /// The failure of every key out of date because of an operation numbered
  /// below [issuedBefore], and the earliest such failure of a bulk
  /// operation.
  List<PersistErrorEvent> _allFailuresBefore(int issuedBefore) {
    final bulk = _bulkFailures.firstWhereOrNull((failed) => failed.sequence < issuedBefore);
    return [
      for (final failed in _failures.values)
        if (failed.sequence < issuedBefore) failed.event,
      if (bulk != null) bulk.event,
    ];
  }

  /// The failures that leave one of [keys] out of date because of an
  /// operation numbered below [issuedBefore]: the key's own, or the
  /// latest such failure of a bulk operation when the key has not been
  /// persisted since.
  Set<PersistErrorEvent> _failuresBefore(int issuedBefore, Iterable<String> keys) {
    final bulk = _bulkFailures.lastWhereOrNull((failed) => failed.sequence < issuedBefore);
    final failures = <PersistErrorEvent>{};
    for (final key in keys.map(persistenceKey)) {
      final failed = _failures[key];
      if (failed != null && failed.sequence < issuedBefore) {
        failures.add(failed.event);
      } else if (bulk != null && (_persistedAt[key] ?? -1) < bulk.sequence) {
        failures.add(bulk.event);
      }
    }
    return failures;
  }
}

/// A failed operation: its number and the event it was reported as.
typedef _Failure = ({int sequence, PersistErrorEvent event});
