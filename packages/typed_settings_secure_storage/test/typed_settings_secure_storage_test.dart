import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_backend.dart';
import 'package:typed_settings/typed_settings_contract.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';
import 'package:typed_settings_secure_storage/typed_settings_secure_storage.dart';

/// Writes [storedKey] in the platform's secure storage without going
/// through a [SecureStorage], as native code or another isolate would.
Future<void> _writeOutside(String storedKey, int? value) => value == null
    ? const FlutterSecureStorage().delete(key: storedKey)
    : const FlutterSecureStorage().write(key: storedKey, value: encodeStoredInt(value));

void main() {
  storageConformance('SecureStorage', (observer) {
    FlutterSecureStorage.setMockInitialValues({});
    return SecureStorage.create(storage: const FlutterSecureStorage(), observer: observer);
  }, writeOutside: (_, key, value) => _writeOutside(key, value));

  storageConformance('SecureStorage with a persistence delay', (observer) {
    FlutterSecureStorage.setMockInitialValues({});
    return SecureStorage.create(
      storage: const FlutterSecureStorage(),
      observer: observer,
      persistenceDelay: const Duration(hours: 1),
    );
  }, writeOutside: (_, key, value) => _writeOutside(key, value));

  storageConformance('SecureStorage (named box)', (observer) {
    FlutterSecureStorage.setMockInitialValues({'other.k': 'belongs to another box'});
    return SecureStorage.create(storage: const FlutterSecureStorage(), box: 'settings', observer: observer);
  }, writeOutside: (_, key, value) => _writeOutside('settings.$key', value));

  test('a box name or setting key with the box separator is an ArgumentError', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await expectLater(SecureStorage.create(storage: const FlutterSecureStorage(), box: 'a.b'), throwsArgumentError);

    final storage = await SecureStorage.create(storage: const FlutterSecureStorage(), box: 'settings');
    expect(() => storage.setString('a.b', 'v'), throwsArgumentError);
    expect(() => storage.getString('a.b'), throwsArgumentError);
  });

  test('one open storage per box and options, whichever object carries them, until it is closed', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final storage = await SecureStorage.create(storage: const FlutterSecureStorage(), box: 'a');
    storage.setString('k', 'v');

    // A distinct object with the same options reaches the same items.
    // ignore: prefer_const_constructors
    await expectLater(SecureStorage.create(storage: FlutterSecureStorage(), box: 'a'), throwsStateError);
    await SecureStorage.create(storage: const FlutterSecureStorage(), box: 'b');
    await SecureStorage.create(
      storage: const FlutterSecureStorage(iOptions: IOSOptions(accountName: 'other')),
      box: 'a',
    );

    await storage.close();

    final reopened = await SecureStorage.create(storage: const FlutterSecureStorage(), box: 'a');
    expect(reopened.getString('k'), 'v');
  });

  group('clearAll', () {
    late _GatedPlatform platform;

    setUp(() => FlutterSecureStoragePlatform.instance = platform = _GatedPlatform({'other.k': 'another box'}));

    test('runs after a write still in flight, so the write does not bring its key back', () async {
      final storage = await SecureStorage.create(storage: const FlutterSecureStorage(), box: 'settings');
      platform.writeGate = Completer<void>();
      storage.setString('k', 'v');

      final clearing = storage.clearAll();
      platform.writeGate!.complete();
      await clearing;

      expect(platform.data, isEmpty);
      expect(storage.getString('k'), isNull);
    });

    test('a failed delete is reported and fails the future with a SettingsPersistException', () async {
      final observer = RecordingObserver();
      final storage = await SecureStorage.create(
        storage: const FlutterSecureStorage(),
        box: 'settings',
        observer: observer,
      );
      platform.deleteAllError = StateError('keychain locked');

      await expectLater(storage.clearAll(), throwsA(isA<SettingsPersistException>()));

      expect(observer.events.single, isA<PersistErrorEvent>().having((e) => e.key, 'key', 'settings'));
    });
  });
}

/// The in-memory platform of the plugin, whose writes wait for [writeGate]
/// while it is set and whose `deleteAll` throws [deleteAllError].
final class _GatedPlatform extends TestFlutterSecureStoragePlatform {
  _GatedPlatform(super.data);

  Completer<void>? writeGate;

  Error? deleteAllError;

  @override
  Future<void> write({required String key, required String value, required Map<String, String> options}) async {
    await writeGate?.future;
    await super.write(key: key, value: value, options: options);
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    if (deleteAllError case final error?) throw error;
    await super.deleteAll(options: options);
  }
}
