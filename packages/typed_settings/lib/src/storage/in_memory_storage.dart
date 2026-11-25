import 'package:meta/meta.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/storage/settings_storage_base.dart';

/// A [SettingsStorage] that keeps its values in memory and persists
/// nothing: for tests, previews and examples, and for settings meant to
/// be ephemeral. Every mutation is complete on return; `flush` has
/// nothing to wait for.
///
/// It holds any object, so a fake of a storage with a type of its own is
/// a subclass whose getter and setter for that type call [readValue] and
/// [writeValue].
base class InMemoryStorage extends SettingsStorageBase {
  /// Creates an empty storage.
  InMemoryStorage({
    super.observer,
  });

  final Map<String, Object?> _store = {};

  /// Reads [key] as [T]; a value of another type is reported and read as
  /// absent, per the typed getter contract of [SettingsStorage].
  @protected
  T? readValue<T extends Object>(String key) {
    checkOpen('read of `$key`');
    final raw = _store[key];
    if (raw == null) return null;
    if (raw is T) return raw;
    reportReadError(key, raw, FormatException('Expected $T, got ${raw.runtimeType}'));
    return null;
  }

  /// Stores [value] under [key] and notifies the key's listeners.
  @protected
  void writeValue(String key, Object value) => _set(key, value);

  void _set(String key, Object? value) {
    checkOpen('write of `$key`');
    _store[key] = value;
    notifyKeyChanged(key);
  }

  @override
  bool? getBool(String key) => readValue<bool>(key);

  @override
  void setBool(String key, bool value) => writeValue(key, value);

  @override
  int? getInt(String key) => readValue<int>(key);

  @override
  void setInt(String key, int value) => writeValue(key, value);

  @override
  double? getDouble(String key) => readValue<double>(key);

  @override
  void setDouble(String key, double value) => writeValue(key, value);

  @override
  String? getString(String key) => readValue<String>(key);

  @override
  void setString(String key, String value) => writeValue(key, value);

  @override
  void remove(String key) {
    checkOpen('remove of `$key`');
    _store.remove(key);
    notifyKeyChanged(key);
  }

  @override
  void setNull(String key) => _set(key, null);

  @override
  bool hasNull(String key) {
    checkOpen('read of `$key`');
    return _store.containsKey(key) && _store[key] == null;
  }

  @override
  Iterable<String> get keys {
    checkOpen('read of keys');
    return List.unmodifiable(_store.keys);
  }

  /// In-memory storage persists nothing, so there is never anything pending
  /// and this never fails.
  @override
  Future<void> flush({Iterable<String>? keys}) async {}

  /// Nothing outside this storage holds its values, so there is nothing
  /// to load.
  @override
  Future<void> reload() async => checkOpen('reload');

  @override
  Future<void> clear() async {
    checkOpen('clear');
    _store.clear();
    notifyAllKeysChanged();
  }

  /// A copy of the entries, for assertions in tests.
  Map<String, Object?> get contents => Map.unmodifiable(_store);
}
