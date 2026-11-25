import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';
import 'package:typed_settings_shared_preferences/typed_settings_shared_preferences.dart';

/// Writes the preference [storedKey] natively on the platform, as native
/// code or another isolate would.
Future<void> _writeOutside(String storedKey, int? value) async {
  final prefs = SharedPreferencesAsync();
  if (value == null) {
    await prefs.remove(storedKey);
  } else {
    await prefs.setInt(storedKey, value);
  }
}

void main() {
  late RecordingObserver observer;

  Future<SharedPreferencesStorage> create(Map<String, Object> initial, {String box = ''}) {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(initial);
    return SharedPreferencesStorage.create(box: box, observer: observer);
  }

  setUp(() => observer = RecordingObserver());

  storageConformance('SharedPreferencesStorage', (observer) {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    return SharedPreferencesStorage.create(observer: observer);
  }, writeOutside: (_, key, value) => _writeOutside(key, value));

  storageConformance('SharedPreferencesStorage with a persistence delay', (observer) {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    return SharedPreferencesStorage.create(observer: observer, persistenceDelay: const Duration(hours: 1));
  }, writeOutside: (_, key, value) => _writeOutside(key, value));

  storageConformance('SharedPreferencesStorage (named box)', (observer) {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData({'other.k': 1});
    return SharedPreferencesStorage.create(box: 'settings', observer: observer);
  }, writeOutside: (_, key, value) => _writeOutside('settings.$key', value));

  group('typed getter contract', () {
    test('a value of another type is reported and reads as absent instead of throwing', () async {
      final storage = await create({'k': 'stext'});

      expect(storage.getInt('k'), isNull);
      expect(storage.getDouble('k'), isNull);
      expect(storage.getBool('k'), isNull);
      expect(storage.getString('k'), 'text');

      expect(observer.events, hasLength(3));
      for (final event in observer.events) {
        expect(
          event,
          isA<StorageReadErrorEvent>().having((e) => e.key, 'key', 'k').having((e) => e.raw, 'raw', 'text'),
        );
      }
    });

    test('the event carries the setting key, not the box-prefixed one', () async {
      final storage = await create({'settings.k': 42}, box: 'settings');

      expect(storage.getString('k'), isNull);
      expect(
        observer.events.single,
        isA<StorageReadErrorEvent>().having((e) => e.key, 'key', 'k').having((e) => e.raw, 'raw', 42),
      );
    });

    test('values stored natively read as their type, and the null marker as null', () async {
      final storage = await create({'i': 1, 'b': true, 'd': 1.5, 'n': 'n'});

      expect(storage.getInt('i'), 1);
      expect(storage.getBool('b'), isTrue);
      expect(storage.getDouble('d'), 1.5);
      expect(storage.getString('n'), isNull);
      expect(storage.hasNull('n'), isTrue);
      expect(observer.events, isEmpty);
    });

    test('a string this encoding did not write is reported when read', () async {
      final storage = await create({'k': 'plain'});

      expect(storage.getString('k'), isNull);
      expect(observer.events.single, isA<StorageReadErrorEvent>().having((e) => e.raw, 'raw', 'plain'));
    });

    test('a string list, which no setting stores, is not a key of the box', () async {
      final storage = await create({
        'k': ['a'],
      });

      expect(storage.keys, isEmpty);
      expect(storage.getString('k'), isNull);
    });
  });

  test('a box name with the separator is an ArgumentError', () async {
    await expectLater(create({}, box: 'a.b'), throwsArgumentError);
    await expectLater(create({}, box: 'a.b'), throwsArgumentError, reason: 'the rejected name claimed nothing');
  });

  test('a dotted key of the unnamed box is not the key of a named box', () async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    final rest = await SharedPreferencesStorage.create();
    final user = await SharedPreferencesStorage.create(box: 'user');

    rest.setInt('user.age', 1);
    user.setInt('age', 2);
    await Future.wait([rest.flush(), user.flush()]);

    expect(rest.getInt('user.age'), 1);
    expect(user.getInt('age'), 2);
    expect(await SharedPreferencesAsync().getKeys(), {r'user\.age', 'user.age'});
    expect(await SharedPreferencesAsync().getInt(r'user\.age'), 1);
    expect(await SharedPreferencesAsync().getInt('user.age'), 2);
    expect(rest.keys, ['user.age']);
    expect(user.keys, ['age']);

    await rest.clear();
    expect(user.getInt('age'), 2);
    expect(await SharedPreferencesAsync().getKeys(), {'user.age'});
  });

  test('a key with dots and backslashes round-trips in a named box', () async {
    final storage = await create({}, box: 'user');

    storage.setString(r'a.b\c', 'v');

    expect(storage.getString(r'a.b\c'), 'v');
    expect(storage.keys, [r'a.b\c']);
  });

  test('one open storage per box, until it is closed', () async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    final storage = (await SharedPreferencesStorage.create(box: 'a'))..setInt('k', 1);

    await expectLater(SharedPreferencesStorage.create(box: 'a'), throwsStateError);
    await SharedPreferencesStorage.create(box: 'b');

    await storage.close();

    expect((await SharedPreferencesStorage.create(box: 'a')).getInt('k'), 1);
  });

  test('a write the platform fails leaves the key unpersisted, found by its setting key', () async {
    SharedPreferencesAsyncPlatform.instance = _ThrowingPlatform();
    final storage = await SharedPreferencesStorage.create(box: 'settings', observer: observer)
      ..setInt('k', 1);

    await expectLater(
      storage.flush(keys: ['k']),
      throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['settings.k'])),
    );
    await storage.flush(keys: ['other']);
    expect(observer.events.single, isA<PersistErrorEvent>());
  });

  test('a reload drops a value the platform never stored, and flush no longer fails for its key', () async {
    SharedPreferencesAsyncPlatform.instance = _ThrowingPlatform();
    final storage = await SharedPreferencesStorage.create(box: 'settings', observer: observer)
      ..setInt('k', 1);
    await expectLater(storage.flush(), throwsA(isA<SettingsPersistException>()));
    var notified = 0;
    storage.addKeyListener('k', () => notified++);

    await storage.reload();

    expect(storage.getInt('k'), isNull);
    expect(notified, 1);
    await storage.flush();
  });
}

final class _ThrowingPlatform extends InMemorySharedPreferencesAsync {
  _ThrowingPlatform() : super.empty();

  @override
  Future<bool> setBool(String key, bool value, SharedPreferencesOptions options) async => throw StateError('disk full');

  @override
  Future<bool> setInt(String key, int value, SharedPreferencesOptions options) async => throw StateError('disk full');

  @override
  Future<bool> setDouble(String key, double value, SharedPreferencesOptions options) async =>
      throw StateError('disk full');

  @override
  Future<bool> setString(String key, String value, SharedPreferencesOptions options) async =>
      throw StateError('disk full');
}
