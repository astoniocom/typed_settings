import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_backend.dart';

/// A [StringBackedStorage] over [FlutterSecureStorage].
///
/// Boxes share one [FlutterSecureStorage] key space, separated by the
/// `<box>.` prefix. To keep boxes isolated, box names and setting keys must
/// not contain `.` (an [ArgumentError] reports one that does); the unnamed
/// box (`box: ''`) owns exactly the keys without a `.`.
///
/// Obtain an instance with [create], which loads the box into memory. It
/// can only do so through [FlutterSecureStorage.readAll], which reads and
/// decrypts every item stored with the same options: every box, and
/// anything else the application keeps there. A box that is loaded on its
/// own, or that sits next to many other secrets, therefore gets a
/// [FlutterSecureStorage] of its own where the platform scopes one: a
/// distinct `accountName` in the Apple options, `storageNamespace` in the
/// Android options, `dbName` in the web options. Linux and Windows offer no
/// such scope; boxes there share one, isolated by the prefix alone. Moving
/// an existing box to a scope of its own leaves its data in the old scope:
/// copy it over in a migration.
///
/// [batch] coalesces a burst down to one write per key, sent in order when
/// the burst returns. There is no atomic multi-key write here, so those
/// writes are still one item at a time, and a throw does not roll the
/// burst back.
///
/// One open storage at a time may serve a box of one scope (see the
/// lifecycle section of `SettingsStorage`). The scope is told by the
/// options: two [FlutterSecureStorage] objects with equal options are one
/// scope, whichever is passed. Options that differ only in what does not
/// select a scope (an accessibility setting) count as another scope, so
/// give each scope one set of options.
final class SecureStorage extends StringBackedStorage {
  SecureStorage._({
    required FlutterSecureStorage storage,
    required _SecureKeys keys,
    required super.cache,
    super.observer,
    super.persistenceDelay,
  }) : _storage = storage,
       _keys = keys,
       box = keys.box,
       super(keyMapping: keys, serves: BackendBox(_SecureStorageScope.of(storage), keys.box));

  /// Loads [box] and returns the storage over it; see the class
  /// documentation for what is loaded. An [ArgumentError] for a [box]
  /// containing `.`, or for a [persistenceDelay] that is zero or negative.
  /// A [StateError] when an open storage already serves [box] with the
  /// same options.
  ///
  /// [persistenceDelay] holds each single-key write and keeps only the
  /// latest value of that key, until the duration has passed without a
  /// newer write. Reads see the new value at once. `flush`, `commit` and
  /// `close` start a held write instead of waiting the duration out.
  static Future<SecureStorage> create({
    required FlutterSecureStorage storage,
    String box = '',
    SettingsObserver? observer,
    Duration? persistenceDelay,
  }) async {
    final keys = _SecureKeys(box);

    return SecureStorage._(
      storage: storage,
      keys: keys,
      cache: await _load(storage, keys),
      observer: observer,
      persistenceDelay: persistenceDelay,
    );
  }

  /// The items of the box of [keys], out of everything [storage] holds.
  static Future<Map<String, String>> _load(FlutterSecureStorage storage, _SecureKeys keys) async {
    final all = await storage.readAll();
    return {
      for (final entry in all.entries)
        if (keys.settingKey(entry.key) != null) entry.key: entry.value,
    };
  }

  final FlutterSecureStorage _storage;

  final _SecureKeys _keys;

  /// The box this storage serves; `''` for the unnamed box.
  final String box;

  /// Reads the box again, which reads and decrypts every item of the
  /// scope like [create] does (see the class documentation).
  @override
  Future<Map<String, String>> loadRaw() => _load(_storage, _keys);

  @override
  Future<void> writeRaw(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> deleteRaw(String key) => _storage.delete(key: key);

  /// Removes everything in the underlying [FlutterSecureStorage], including
  /// other boxes; [clear] removes only this box. The cache is cleared
  /// first, and the delete runs after every write issued before it. A
  /// failure is reported to the observer and fails the returned future
  /// with a `SettingsPersistException`, like [clear].
  Future<void> clearAll() {
    checkOpen('clearAll');
    return clearAtOnce(box, _storage.deleteAll);
  }
}

/// The keys of one box in the platform's key space, separated by the
/// `<box>.` prefix. Neither a box name nor a setting key may contain `.`,
/// so a stored key belongs to the box whose prefix it starts with, and to
/// the unnamed box when it has no `.` at all.
final class _SecureKeys implements KeyMapping {
  /// The keys of [box]; an [ArgumentError] when it contains `.`.
  _SecureKeys(this.box) {
    if (box.contains(_separator)) {
      throw ArgumentError.value(box, 'box', 'must not contain `$_separator`');
    }
  }

  static const String _separator = '.';

  final String box;

  /// [key] with the box prefix; an [ArgumentError] when it contains `.`.
  @override
  String storedKey(String key) {
    if (key.contains(_separator)) {
      throw ArgumentError.value(key, 'key', 'must not contain `$_separator`');
    }
    return box.isEmpty ? key : '$box$_separator$key';
  }

  @override
  String? settingKey(String storedKey) {
    if (box.isEmpty) return storedKey.contains(_separator) ? null : storedKey;
    final prefix = '$box$_separator';
    return storedKey.startsWith(prefix) ? storedKey.substring(prefix.length) : null;
  }
}

/// The scope of the platform's secure storage that a set of options
/// selects: what a [SecureStorage] persists through. Equal options give the
/// same object, whichever [FlutterSecureStorage] carries them.
final class _SecureStorageScope {
  _SecureStorageScope._();

  /// The scopes of each platform implementation by their options, so that a
  /// platform replaced (by a test's mock) starts with none.
  static final Expando<Map<String, _SecureStorageScope>> _byOptions = Expando('typed_settings: secure storage scopes');

  static _SecureStorageScope of(FlutterSecureStorage storage) {
    final options = jsonEncode([
      storage.iOptions.toMap(),
      storage.aOptions.toMap(),
      storage.lOptions.toMap(),
      storage.wOptions.toMap(),
      storage.webOptions.toMap(),
      storage.mOptions.toMap(),
    ]);
    return (_byOptions[FlutterSecureStoragePlatform.instance] ??= {}).putIfAbsent(options, _SecureStorageScope._);
  }
}
