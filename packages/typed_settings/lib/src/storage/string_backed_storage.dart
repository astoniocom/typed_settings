import 'dart:async';

import 'package:meta/meta.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/storage/settings_storage_base.dart';
import 'package:typed_settings/src/storage_kit/background_persistence.dart';
import 'package:typed_settings/src/storage_kit/key_mapping.dart';
import 'package:typed_settings/src/storage_kit/scalar_string_encoding.dart';

/// A [SettingsStorage] for backends that can only store strings.
///
/// Keeps every value as a string in an in-memory cache (pre-loaded through
/// the constructor) so reads are synchronous, and writes through to the
/// backend in the background. All typed values, explicit `null`, removal,
/// `flush()` and error reporting are implemented here; a backend provides
/// just [writeRaw] and [deleteRaw], plus a [keyMapping] when it shares its
/// backend with other storages (a box prefix). Everything that goes from
/// a setting key to the backend and back ([keys], `clear`, a scoped
/// `flush`) follows that one mapping.
///
/// Undecodable stored strings are reported to the observer and read as absent.
///
/// [batch] holds those writes back and hands each key's final state to
/// [writeBatchRaw] once, when the outermost call returns. The default
/// [writeBatchRaw] then writes them one after another; override it where
/// the backend can do them in one round trip. See [SettingsStorage.batch]: this is
/// not a transaction, and listeners are still told of every write.
abstract base class StringBackedStorage extends SettingsStorageBase {
  /// [cache] holds the backend's current contents, keyed by stored key
  /// ([KeyMapping.storedKey] of [keyMapping]); it is owned by the storage
  /// from now on. It may hold the keys of other storages that share the
  /// backend: this storage never reads, lists or clears a key that
  /// [keyMapping] does not take for its own. [maxConcurrentOperations] goes
  /// to [BackgroundPersistence.maxConcurrentOperations] (an [ArgumentError]
  /// when it is below one). [persistenceDelay] is
  /// [BackgroundPersistence.persistenceDelay]: each single-key write is
  /// held, and only its latest value is written, until the delay passes
  /// without a newer write of that key. The cache is updated in the call
  /// either way. `flush` and `close` start a held write instead of waiting
  /// the delay out. An [ArgumentError] when it is zero or negative. The
  /// other parameters go to [SettingsStorageBase].
  StringBackedStorage({
    required Map<String, String> cache,
    this.keyMapping = KeyMapping.identity,
    int maxConcurrentOperations = 1,
    Duration? persistenceDelay,
    super.observer,
    super.serves,
  }) : _cache = cache,
       _maxConcurrentOperations = _checkConcurrency(maxConcurrentOperations),
       _persistenceDelay = _checkDelay(persistenceDelay) {
    _persistence = BackgroundPersistence(
      report: observer.report,
      persistenceKey: _resolveKey,
      maxConcurrentOperations: _maxConcurrentOperations,
      persistenceDelay: _persistenceDelay,
    );
  }

  static Duration? _checkDelay(Duration? delay) {
    if (delay != null && delay <= Duration.zero) {
      throw ArgumentError.value(delay, 'persistenceDelay', 'must be positive');
    }
    return delay;
  }

  static int _checkConcurrency(int value) {
    if (value < 1) throw ArgumentError.value(value, 'maxConcurrentOperations', 'must be at least 1');
    return value;
  }

  final int _maxConcurrentOperations;

  /// Checked before the superclass claims the box: a throw from the
  /// constructor body would leave the box taken.
  final Duration? _persistenceDelay;

  /// Persists the writes in the background, by resolved key.
  late final BackgroundPersistence _persistence;

  final Map<String, String> _cache;

  /// How setting keys map onto the keys of the backend, both ways; the
  /// identity unless the backend holds other storages' keys too.
  final KeyMapping keyMapping;

  /// Writes [value] under the resolved [key] in the backend.
  @protected
  Future<void> writeRaw(String key, String value);

  /// Deletes the resolved [key] from the backend.
  @protected
  Future<void> deleteRaw(String key);

  /// Reads what the backend holds now, by resolved key: what the `cache`
  /// given to the constructor would be for a storage created at this
  /// moment. Called by [reload], possibly while writes of other keys are
  /// in flight. Keys of other storages that share the backend may be
  /// included; [keyMapping] tells them apart.
  @protected
  Future<Map<String, String>> loadRaw();

  /// Persists the writes of one `batch` together: [upserts] by resolved
  /// key, then [deletes]; a key appears in at most one of them. Override
  /// where the backend can do this in one round trip or transaction; the
  /// default calls [writeRaw] and [deleteRaw] one by one.
  @protected
  Future<void> writeBatchRaw(Map<String, String> upserts, Iterable<String> deletes) async {
    for (final entry in upserts.entries) {
      await writeRaw(entry.key, entry.value);
    }
    for (final key in deletes) {
      await deleteRaw(key);
    }
  }

  String _resolveKey(String key) => keyMapping.storedKey(key);

  /// Nesting depth of `batch`; while positive, writes are collected in
  /// [_batched] instead of being persisted one by one.
  int _batchDepth = 0;

  /// The final state of each resolved key written inside the current
  /// batch: a string to upsert, or `null` to delete.
  final Map<String, String?> _batched = {};

  /// Completes once the outermost batch has handed its writes over; `null`
  /// outside a batch.
  Completer<void>? _batchHandedOver;

  /// See [SettingsStorage.batch].
  @override
  void batch(void Function() mutations) {
    if (_batchDepth == 0) _batchHandedOver = Completer<void>();
    _batchDepth++;
    try {
      mutations();
    } finally {
      _batchDepth--;
      if (_batchDepth == 0) {
        try {
          _persistBatched();
        } finally {
          _batchHandedOver!.complete();
          _batchHandedOver = null;
        }
      }
    }
  }

  /// A flush issued inside a batch waits until the outermost batch has
  /// handed its writes over, so that it covers them.
  @override
  Future<void> flush({Iterable<String>? keys}) async {
    final handedOver = _batchHandedOver;
    if (handedOver != null) await handedOver.future;
    await _persistence.flush(keys: keys);
  }

  void _persistBatched() {
    if (_batched.isEmpty) return;
    final upserts = <String, String>{};
    final deletes = <String>[];
    for (final entry in _batched.entries) {
      final value = entry.value;
      if (value == null) {
        deletes.add(entry.key);
      } else {
        upserts[entry.key] = value;
      }
    }
    _batched.clear();
    _persistence.persist(PersistTarget.keys([...upserts.keys, ...deletes]), () => writeBatchRaw(upserts, deletes));
  }

  // Two layers of private helpers. The `*Resolved` ones work on resolved
  // keys (the cache's and the backend's key space) and only touch state;
  // the others take setting keys, resolve them and notify listeners. The
  // cache has no reverse mapping, which is why `clear` must work on the
  // resolved layer.

  /// The resolved keys written or removed while a [reload] reads the
  /// backend, whose state is newer than what it loads; `null` while no
  /// reload is running.
  Set<String>? _changedDuringReload;

  /// Whether the cache was cleared while a [reload] reads the backend, so
  /// that nothing it loads is current any more.
  bool _clearedDuringReload = false;

  /// The end of the latest [reload], so that the next one starts after it.
  Future<void>? _reloading;

  /// See [SettingsStorage.reload]. Reloads take turns: one called while
  /// another is running reads the backend again once that one is done.
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
    _clearedDuringReload = false;
    final Map<String, String> loaded;
    try {
      final handedOver = _batchHandedOver;
      if (handedOver != null) await handedOver.future;
      await _persistence.pendingOperationsSettled();
      loaded = await loadRaw();
    } finally {
      _changedDuringReload = null;
    }
    // Closed meanwhile: nothing reads this storage any more. Cleared
    // meanwhile: the clear is newer than everything that was loaded.
    if (isClosed || _clearedDuringReload) return;

    final notified = <String>[];
    for (final resolvedKey in {..._cache.keys, ...loaded.keys}) {
      if (changed.contains(resolvedKey)) continue;
      final key = keyMapping.settingKey(resolvedKey);
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

  /// Stores [raw] under [resolvedKey] in the cache and the backend.
  void _writeResolved(String resolvedKey, String raw) {
    _changedDuringReload?.add(resolvedKey);
    _cache[resolvedKey] = raw;
    if (_batchDepth > 0) {
      _batched[resolvedKey] = raw;
    } else {
      _persistence.persist(PersistTarget.key(resolvedKey), () => writeRaw(resolvedKey, raw));
    }
  }

  /// Drops [resolvedKey] from the cache and the backend.
  void _deleteResolved(String resolvedKey) {
    _changedDuringReload?.add(resolvedKey);
    _cache.remove(resolvedKey);
    if (_batchDepth > 0) {
      _batched[resolvedKey] = null;
    } else {
      _persistence.persist(PersistTarget.key(resolvedKey), () => deleteRaw(resolvedKey));
    }
  }

  /// The scalar stored for [key], or `null` when the key is absent. An
  /// explicit null is [EncodedNull], not `null`: the two states differ.
  EncodedScalar? _read(String key) {
    checkOpen('read of `$key`');
    final raw = _cache[_resolveKey(key)];
    if (raw == null) return null;
    return decodeStoredScalar(raw);
  }

  /// Reports [stored] as not an [expected] and reads it as absent.
  T? _wrongType<T>(String key, EncodedScalar stored, String expected) {
    reportReadError(key, stored.reportable, FormatException(expected));
    return null;
  }

  /// Stores [raw] under [key] and notifies its listeners.
  void _write(String key, String raw) {
    checkOpen('write of `$key`');
    _writeResolved(_resolveKey(key), raw);
    notifyKeyChanged(key);
  }

  /// Deletes every key of this storage in one operation through
  /// [writeBatchRaw], so a backend with a bulk call makes one round trip:
  /// the cached keys that [keyMapping] takes for this storage's, as [keys]
  /// lists them. A key of another storage that shares the backend stays,
  /// in the cache and in the backend. The operation runs after every
  /// pending write of those keys, so none of them resurrects a key. Inside
  /// a batch the deletions join the batch, replacing what it wrote so far.
  @override
  Future<void> clear() {
    checkOpen('clear');
    final deleted = [
      for (final storedKey in _cache.keys)
        if (keyMapping.settingKey(storedKey) != null) storedKey,
    ];
    if (_batchDepth > 0) {
      deleted.forEach(_deleteResolved);
    } else if (deleted.isNotEmpty) {
      _clearedDuringReload = true;
      deleted.forEach(_cache.remove);
      _persistence.persist(PersistTarget.keys(deleted), () => writeBatchRaw(const {}, deleted));
    }
    notifyAllKeysChanged();
    return flush();
  }

  /// Clears with one backend call, [deleteAll], instead of the per-key
  /// deletion of [clear]: for a backend whose call drops everything this
  /// storage holds at once (`DELETE ... WHERE box = ?`). The caller checks
  /// that the storage is open first.
  ///
  /// Forgets every cached entry, those of other storages that share the
  /// backend included, and inside a batch the writes the batch has
  /// collected so far: the clear supersedes them, and they must not reach
  /// the backend after it. Notifies every listener, and runs [deleteAll]
  /// after every operation handed over before it, so that none of them
  /// resurrects a key. A failure is reported under [label] (typically the
  /// box) and fails the returned future, like a write that did not
  /// persist; a later successful [deleteAll] brings every key up to date.
  @protected
  Future<void> clearAtOnce(String label, Future<void> Function() deleteAll) {
    _clearedDuringReload = true;
    _cache.clear();
    _batched.clear();
    notifyAllKeysChanged();
    _persistence.persist(PersistTarget.all(label), deleteAll);
    return flush();
  }

  @override
  void remove(String key) {
    checkOpen('remove of `$key`');
    _deleteResolved(_resolveKey(key));
    notifyKeyChanged(key);
  }

  @override
  void setNull(String key) => _write(key, encodeStoredNull());

  @override
  bool hasNull(String key) => _read(key) is EncodedNull;

  /// Setting keys that hold something: the cached keys that [keyMapping]
  /// takes for this storage's, mapped back to setting keys.
  @override
  Iterable<String> get keys {
    checkOpen('read of keys');
    return [
      for (final storedKey in _cache.keys) ?keyMapping.settingKey(storedKey),
    ];
  }

  @override
  String? getString(String key) => switch (_read(key)) {
    null || EncodedNull() => null,
    EncodedString(:final value) => value,
    final stored => _wrongType(key, stored, 'Expected a string'),
  };

  @override
  void setString(String key, String value) => _write(key, encodeStoredString(value));

  @override
  bool? getBool(String key) => switch (_read(key)) {
    null || EncodedNull() => null,
    EncodedBool(:final value) => value,
    final stored => _wrongType(key, stored, 'Expected a bool'),
  };

  @override
  void setBool(String key, bool value) => _write(key, encodeStoredBool(value));

  @override
  int? getInt(String key) => switch (_read(key)) {
    null || EncodedNull() => null,
    EncodedInt(:final value) => value,
    final stored => _wrongType(key, stored, 'Expected an int'),
  };

  @override
  void setInt(String key, int value) => _write(key, encodeStoredInt(value));

  @override
  double? getDouble(String key) => switch (_read(key)) {
    null || EncodedNull() => null,
    EncodedDouble(:final value) => value,
    final stored => _wrongType(key, stored, 'Expected a double'),
  };

  @override
  void setDouble(String key, double value) => _write(key, encodeStoredDouble(value));
}
