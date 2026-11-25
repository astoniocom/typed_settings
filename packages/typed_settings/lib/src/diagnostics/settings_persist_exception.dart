import 'package:typed_settings/src/diagnostics/settings_event.dart';

/// The storage could not persist some keys: the latest persistence of each
/// of them failed and nothing has persisted the key since, so after a
/// restart they would not read what the application last wrote.
///
/// Thrown by `SettingsStorage.flush`, and by `clear`, whose future includes
/// a flush. Every failure has also been reported to the storage's observer
/// as a [PersistErrorEvent] when it happened; this exception is for code
/// that must not go on while the persisted state is incomplete, such as
/// `SettingsMigrator`.
final class SettingsPersistException implements Exception {
  /// Creates the exception for [failures], the first failure of each key
  /// that is out of date; there is at least one (an [ArgumentError]
  /// reports an empty one).
  SettingsPersistException(Iterable<PersistErrorEvent> failures) : failures = List.unmodifiable(failures) {
    if (this.failures.isEmpty) throw ArgumentError.value(failures, 'failures', 'must not be empty');
  }

  /// The first failure of each out-of-date key, as reported to the observer.
  final List<PersistErrorEvent> failures;

  /// The keys that are out of date, as the backend persists them: a
  /// box-scoped backend may prefix them, and a bulk operation over a whole
  /// box is named after the box.
  Iterable<String> get keys => failures.map((failure) => failure.key!);

  @override
  String toString() =>
      'SettingsPersistException: not persisted: ${keys.map((key) => '`$key`').join(', ')}; first error: ${failures.first.reportableError}';
}
