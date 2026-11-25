import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_backend.dart';

/// A [SettingsStorage] over [SharedPreferencesAsync].
///
/// `bool`, `int` and `double` use the platform's own types. The platform
/// has no null value, and a string shares that type with an explicit null,
/// so both use the string encoding (`encodeStoredString`,
/// `encodeStoredNull`): a string is tagged, so it cannot be the null tag.
///
/// The storage keeps the box in its own cache. [SharedPreferencesAsync]
/// holds nothing that can be read synchronously, and it does not order its
/// writes, so a write updates the cache at once and the platform call is
/// handed to the queue (see [BackgroundPersistence.persist]).
/// `SharedPreferencesWithCache` is not used: its writes reach the platform
/// in no guaranteed order, and its reload empties the cache while it
/// fetches.
///
/// Boxes share the preference key space, separated by the `<box>.` prefix,
/// as [BoxKeySpace] lays them out: box names must not contain `.` or `\`
/// (an [ArgumentError] reports one that does), and `.` and `\` of a
/// setting key are escaped, so that the key `user.age` of the unnamed box
/// is not the key `age` of the box `user`.
///
/// [create] loads every preference of the application, whatever the box
/// (see the loading section of `SettingsStorage`): the platform has no way
/// to read keys by prefix. [reload] reads them all again.
///
/// One open storage at a time may serve a box (see the lifecycle section
/// of `SettingsStorage`), whatever [SharedPreferencesOptions] each was
/// created with; [create] throws a [StateError] for a box already served.
base class SharedPreferencesStorage extends SettingsStorageBase {
  SharedPreferencesStorage._(
    this._prefs,
    this._keys,
    Map<String, Object> cache,
    SettingsObserver? observer,
    Duration? persistenceDelay,
  ) : _cache = cache,
      _persistence = BackgroundPersistence(
        report: (observer ?? const DefaultSettingsObserver()).report,
        persistenceKey: _keys.storedKey,
        persistenceDelay: persistenceDelay,
      ),
      super(observer: observer, serves: BackendBox(SharedPreferencesAsyncPlatform.instance!, _keys.box));

  /// Loads [box] and returns the storage over it. [options] go to
  /// [SharedPreferencesAsync] (the Android backend, for one). An
  /// [ArgumentError] for a [box] containing `.` or `\`, or for a
  /// [persistenceDelay] that is zero or negative. A [StateError] when an
  /// open storage already serves [box] or when no shared_preferences
  /// platform implementation is registered.
  ///
  /// [persistenceDelay] holds each single-key write and keeps only the
  /// latest value of that key, until the duration has passed without a
  /// newer write. Reads see the new value at once. `flush`, `commit` and
  /// `close` start a held write instead of waiting the duration out.
  static Future<SharedPreferencesStorage> create({
    String box = '',
    SharedPreferencesOptions options = const SharedPreferencesOptions(),
    SettingsObserver? observer,
    Duration? persistenceDelay,
  }) async {
    final keys = BoxKeySpace(box);
    final prefs = SharedPreferencesAsync(options: options);
    return SharedPreferencesStorage._(prefs, keys, await _load(prefs, keys), observer, persistenceDelay);
  }

  final SharedPreferencesAsync _prefs;

  final BoxKeySpace _keys;

  /// The platform's values of this box, by resolved key. An explicit null
  /// is the encoded string, never a missing entry.
  final Map<String, Object> _cache;

  /// The box this storage serves; `''` for the unnamed box.
  String get box => _keys.box;

  String _resolveKey(String key) => _keys.storedKey(key);

  /// Persistence is handed over by resolved key.
  final BackgroundPersistence _persistence;

  @override
  Future<void> flush({Iterable<String>? keys}) => _persistence.flush(keys: keys);

  /// The preferences of the box of [keys]. A string list, which no setting
  /// stores, is left out.
  static Future<Map<String, Object>> _load(SharedPreferencesAsync prefs, BoxKeySpace keys) async {
    final all = await prefs.getAll();
    return {
      for (final MapEntry(:key, :value) in all.entries)
        if (keys.settingKey(key) != null) key: ?_cached(value),
    };
  }

  /// [value] as the cache holds it; `null` for a string list.
  static Object? _cached(Object? value) => switch (value) {
    final String value => value,
    final bool value => value,
    final int value => value,
    final double value => value,
    _ => null,
  };

  /// Reads [key] as [T]; a value of another type is reported and read as
  /// absent, per the typed getter contract of [SettingsStorage]. An explicit
  /// null reads as `null` without a report. A string this encoding did not
  /// write is not a string value: it is reported too.
  T? _get<T extends Object>(String key) {
    checkOpen('read of `$key`');
    final raw = _cache[_resolveKey(key)];
    if (raw == null) return null;
    if (raw is String) {
      final decoded = decodeStoredScalar(raw);
      return switch (decoded) {
        EncodedNull() => null,
        EncodedString(:final value) when value is T => value as T,
        _ => _wrongType(key, decoded),
      };
    }
    if (raw is T) return raw;
    reportReadError(
      key,
      raw,
      FormatException('Expected $T, got ${raw.runtimeType}'),
    );
    return null;
  }

  T? _wrongType<T>(String key, EncodedScalar stored) {
    reportReadError(
      key,
      stored.reportable,
      FormatException('Expected $T, got ${stored.reportable.runtimeType}'),
    );
    return null;
  }

  /// Updates the cache at once, so the mutation is visible before it
  /// reaches the platform, and hands [write] to the queue. [SharedPreferencesAsync]
  /// neither updates a cache inside the call nor orders its calls, so the
  /// call itself waits its turn.
  void _mutate(String key, Future<void> Function(String resolvedKey) write, {Object? value, bool remove = false}) {
    checkOpen('write of `$key`');
    final resolvedKey = _resolveKey(key);
    _changedDuringReload?.add(resolvedKey);
    if (remove) {
      _cache.remove(resolvedKey);
    } else {
      _cache[resolvedKey] = value!;
    }
    _persistence.persist(PersistTarget.key(resolvedKey), () => write(resolvedKey));
    notifyKeyChanged(key);
  }

  @override
  void setNull(String key) => _mutate(
    key,
    (k) => _prefs.setString(k, encodeStoredNull()),
    value: encodeStoredNull(),
  );

  @override
  bool hasNull(String key) {
    checkOpen('read of `$key`');
    final raw = _cache[_resolveKey(key)];
    return raw is String && decodeStoredScalar(raw) is EncodedNull;
  }

  @override
  Iterable<String> get keys {
    checkOpen('read of keys');
    return [
      for (final key in _cache.keys) ?_keys.settingKey(key),
    ];
  }

  @override
  bool? getBool(String key) => _get<bool>(key);

  @override
  void setBool(String key, bool value) => _mutate(key, (k) => _prefs.setBool(k, value), value: value);

  @override
  int? getInt(String key) => _get<int>(key);

  @override
  void setInt(String key, int value) => _mutate(key, (k) => _prefs.setInt(k, value), value: value);

  @override
  double? getDouble(String key) => _get<double>(key);

  @override
  void setDouble(String key, double value) => _mutate(key, (k) => _prefs.setDouble(k, value), value: value);

  @override
  String? getString(String key) => _get<String>(key);

  @override
  void setString(String key, String value) => _mutate(
    key,
    (k) => _prefs.setString(k, encodeStoredString(value)),
    value: encodeStoredString(value),
  );

  @override
  void remove(String key) => _mutate(key, _prefs.remove, remove: true);

  /// The resolved keys written, removed or cleared while the current
  /// [reload] reads the platform, whose state is newer than what it loads;
  /// `null` while no reload is running.
  Set<String>? _changedDuringReload;

  /// The end of the latest [reload], so that the next one starts after it.
  Future<void>? _reloading;

  /// Reads the preferences from the platform again: every preference of the
  /// application, the other boxes included. Their storages hold their own
  /// copy, so only the listeners of this box are notified; reload each box
  /// whose settings must hear of it.
  ///
  /// A key written while the platform is read keeps the value written: the
  /// loaded one is older.
  @override
  Future<void> reload() async {
    checkOpen('reload');
    final previous = _reloading;
    final done = Completer<void>();
    _reloading = done.future;
    try {
      if (previous != null) await previous;
      await _reload();
    } finally {
      done.complete();
      if (identical(_reloading, done.future)) _reloading = null;
    }
  }

  Future<void> _reload() async {
    final changed = _changedDuringReload = {};
    final Map<String, Object> loaded;
    try {
      await _persistence.pendingOperationsSettled();
      loaded = await _load(_prefs, _keys);
    } finally {
      _changedDuringReload = null;
    }
    if (isClosed) return;

    final notified = <String>[];
    for (final resolvedKey in {..._cache.keys, ...loaded.keys}) {
      if (changed.contains(resolvedKey)) continue;
      final key = _keys.settingKey(resolvedKey);
      if (key == null) continue;
      final raw = loaded[resolvedKey];
      if (_cache[resolvedKey] == raw) continue;
      if (raw == null) {
        _cache.remove(resolvedKey);
      } else {
        _cache[resolvedKey] = raw;
      }
      notified.add(key);
    }
    _persistence.markReloaded(except: changed);
    notified.forEach(notifyKeyChanged);
  }

  @override
  Future<void> clear() {
    checkOpen('clear');
    final deleted = [
      for (final key in _cache.keys)
        if (_keys.settingKey(key) != null) key,
    ];
    for (final key in deleted) {
      _changedDuringReload?.add(key);
      _cache.remove(key);
      _persistence.persist(PersistTarget.key(key), () => _prefs.remove(key));
    }
    notifyAllKeysChanged();
    return flush();
  }
}
