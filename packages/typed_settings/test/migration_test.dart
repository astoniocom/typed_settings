import 'dart:async';

import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_dao.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

enum Theme { light, dark, system }

const _versionKey = 'schema_version';

void main() {
  late InMemoryStorage storage;

  setUp(() => storage = InMemoryStorage());

  group('legacyKeys', () {
    test('creating the setting and reading it leave the storage untouched; the value comes from the legacy key', () {
      storage.setInt('old', 42);
      var keyChanged = 0;
      storage
        ..addKeyListener('new', () => keyChanged++)
        ..addKeyListener('old', () => keyChanged++);

      final setting = IntSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old'],
        defaultValue: 0,
      );
      expect(setting.value, 42);
      setting.invalidate();
      expect(setting.value, 42);

      expect(storage.contents, {'old': 42}, reason: 'neither creation nor reads write');
      expect(keyChanged, 0);
    });

    test(
      'the first write moves the value to the current key, and removes the legacy keys once it has persisted',
      () async {
        storage
          ..setInt('old', 42)
          ..setInt('older', 41);
        final setting = IntSetting(
          storage: storage,
          key: 'new',
          legacyKeys: const ['old', 'older'],
          defaultValue: 0,
        );

        setting.value = 43;
        expect(storage.contents, {'old': 42, 'older': 41, 'new': 43}, reason: 'the write is not known to persist yet');
        expect(setting.value, 43);

        await pumpEventQueue();
        expect(storage.contents, {'new': 43});
        expect(setting.value, 43);
      },
    );

    test('assigning the value read from a legacy key is a write, not a no-op', () async {
      storage.setInt('old', 42);
      final setting = IntSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old'],
        defaultValue: 0,
      );
      var notified = 0;
      setting.addListener(() => notified++);

      setting.value = 42;
      await pumpEventQueue();

      expect(storage.contents, {'new': 42});
      expect(notified, 1);

      setting.value = 42;
      expect(notified, 1, reason: 'now it is a no-op');
    });

    test('a legacy key populated later is seen, like any storage change of a watched key', () {
      final setting = IntSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old'],
        defaultValue: 0,
      );
      var notified = 0;
      setting.addListener(() => notified++);
      expect(setting.value, 0);

      storage.setInt('old', 42);

      expect(notified, 1);
      expect(setting.value, 42);
    });

    test('the current key wins over legacy keys, and legacy keys are tried in order', () {
      storage
        ..setInt('older', 1)
        ..setInt('old', 2);
      final preferOld = IntSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old', 'older'],
        defaultValue: 0,
      );
      expect(preferOld.value, 2);
      // Both claim `older`, which the registry allows one live setting only.
      preferOld.dispose();

      storage.setInt('current', 3);
      final current = IntSetting(
        storage: storage,
        key: 'current',
        legacyKeys: const ['older'],
        defaultValue: 0,
      );
      expect(current.value, 3);
    });

    test('two instances over one key read the same thing, the legacy value included', () async {
      storage.setInt('old', 42);
      final a = IntSetting(storage: storage, key: 'new', legacyKeys: const ['old'], defaultValue: 0);
      final b = IntSetting(storage: storage, key: 'new', legacyKeys: const ['old'], defaultValue: 0);

      expect(a.value, 42);
      expect(b.value, 42);
      expect(
        () => IntSetting(storage: storage, key: 'new', defaultValue: 0),
        throwsStateError,
        reason: 'one that does not know the legacy key would read 0',
      );

      a.value = 43;
      expect(b.value, 43);
      await pumpEventQueue();
      expect(storage.contents, {'new': 43});
    });

    test('an explicit null under a legacy key reads as null and is moved as an explicit null', () async {
      storage.setNull('old');
      final setting = IntNullableSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old'],
        defaultValue: 7,
      );

      expect(setting.value, isNull);
      setting.value = null;
      await pumpEventQueue();

      expect(storage.hasNull('new'), isTrue);
      expect(storage.hasNull('old'), isFalse);
    });

    test('a non-nullable setting treats an explicit null under a legacy key as absent', () {
      storage.setNull('old');
      final setting = IntSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old'],
        defaultValue: 7,
      );

      expect(setting.value, 7);
    });

    test('without any stored value the default applies and nothing is written', () {
      final setting = IntSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old'],
        defaultValue: 7,
      );
      expect(setting.value, 7);
      expect(storage.contents, isEmpty);
    });

    test('a write does not touch absent legacy keys', () {
      final setting = IntSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old'],
        defaultValue: 0,
      );
      var oldChanged = 0;
      storage.addKeyListener('old', () => oldChanged++);

      setting.value = 1;

      expect(oldChanged, 0);
    });

    test('reset removes legacy keys too, so a legacy value does not resurface', () {
      storage
        ..setInt('old', 5)
        ..setNull('older');
      final setting = IntSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old', 'older'],
        defaultValue: 0,
      );

      setting.reset();

      expect(setting.value, 0);
      expect(storage.contents, isEmpty);
    });

    test('dispose unregisters from the legacy keys as well', () {
      final setting = IntSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old'],
        defaultValue: 0,
      );
      var notified = 0;
      setting.addListener(() => notified++);

      setting.dispose();
      storage.setInt('old', 1);

      expect(notified, 0);
    });

    test('the current key listed as legacy is an ArgumentError: every write would remove what it wrote', () {
      expect(
        () => IntSetting(
          storage: storage,
          key: 'k',
          legacyKeys: const ['k'],
          defaultValue: 0,
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'legacyKeys')),
      );
    });
  });

  group('EnumSetting legacyNames', () {
    test('decodes a renamed constant and writes the current name back', () {
      storage.setString('theme', 'night');
      final setting = EnumSetting<Theme>(
        storage: storage,
        key: 'theme',
        defaultValue: Theme.system,
        values: Theme.values,
        legacyNames: const {'night': Theme.dark},
      );

      expect(setting.value, Theme.dark);
      setting.value = Theme.light;
      setting.value = Theme.dark;
      expect(storage.getString('theme'), 'dark');
    });
  });

  group('SettingsMigrator', () {
    test('applies pending migrations in order and records the version', () async {
      storage.setInt('timeout_seconds', 30);
      final migrator = SettingsMigrator<InMemoryStorage>([
        SettingsMigration(1, (s) {
          final seconds = s.getInt('timeout_seconds');
          if (seconds != null) {
            s
              ..setInt('timeout_ms', seconds * 1000)
              ..remove('timeout_seconds');
          }
        }),
        SettingsMigration(2, (s) => s.setBool('migrated_v2', true)),
      ], versionKey: _versionKey);

      expect(migrator.currentVersion(storage), 0);
      expect(await migrator.run(storage), 2);

      expect(storage.getInt('timeout_ms'), 30000);
      expect(storage.getInt('timeout_seconds'), isNull);
      expect(storage.getBool('migrated_v2'), isTrue);
      expect(migrator.currentVersion(storage), 2);
      expect(migrator.latestVersion, 2);
    });

    test('skips migrations at or below the recorded version', () async {
      storage.setInt(_versionKey, 1);
      final ran = <int>[];
      final migrator = SettingsMigrator<InMemoryStorage>([
        SettingsMigration(1, (s) => ran.add(1)),
        SettingsMigration(2, (s) => ran.add(2)),
      ], versionKey: _versionKey);

      expect(await migrator.run(storage), 1);
      expect(ran, [2]);
      expect(await migrator.run(storage), 0, reason: 'already up to date');
    });

    test('a failing step keeps the last successful version and rethrows', () async {
      final migrator = SettingsMigrator<InMemoryStorage>([
        SettingsMigration(1, (s) => s.setBool('v1', true)),
        SettingsMigration(2, (s) => throw StateError('boom')),
        SettingsMigration(3, (s) => s.setBool('v3', true)),
      ], versionKey: _versionKey);

      await expectLater(migrator.run(storage), throwsStateError);

      expect(migrator.currentVersion(storage), 1);
      expect(storage.getBool('v1'), isTrue);
      expect(storage.getBool('v3'), isNull);
    });

    test('a version newer than the latest step is a downgrade, rejected before any step', () async {
      storage.setInt(_versionKey, 5);
      final ran = <int>[];
      final migrator = SettingsMigrator<InMemoryStorage>([
        SettingsMigration(1, (s) => ran.add(1)),
        SettingsMigration(2, (s) => ran.add(2)),
      ], versionKey: _versionKey);

      await expectLater(
        migrator.run(storage),
        throwsA(
          isA<SettingsDowngradeException>()
              .having((e) => e.recordedVersion, 'recordedVersion', 5)
              .having((e) => e.latestVersion, 'latestVersion', 2),
        ),
      );
      expect(ran, isEmpty);
      expect(migrator.currentVersion(storage), 5);
    });

    test('keeps settings off the version key once it has run', () async {
      final migrator = SettingsMigrator<InMemoryStorage>([SettingsMigration(1, (s) {})], versionKey: _versionKey);
      await migrator.run(storage);

      expect(() => IntSetting(storage: storage, key: _versionKey, defaultValue: 0), throwsStateError);
      expect(
        () => IntSetting(storage: storage, key: 'k', legacyKeys: const [_versionKey], defaultValue: 0),
        throwsStateError,
      );
      expect(await migrator.run(storage), 0, reason: 'running again reserves the same key for the same purpose');
    });

    test('refuses to run over a version key a live setting uses', () async {
      IntSetting(storage: storage, key: _versionKey, defaultValue: 0);
      final migrator = SettingsMigrator<InMemoryStorage>([SettingsMigration(1, (s) {})], versionKey: _versionKey);

      await expectLater(migrator.run(storage), throwsStateError);
      expect(migrator.currentVersion(storage), 0);
    });

    test("modules over one storage keep versions of their own, so neither skips the other's steps", () async {
      final ran = <String>[];
      final profile = SettingsMigrator<InMemoryStorage>([
        SettingsMigration(1, (s) => ran.add('profile 1')),
        SettingsMigration(2, (s) => ran.add('profile 2')),
        SettingsMigration(3, (s) => ran.add('profile 3')),
      ], versionKey: 'profile_version');
      final billing = SettingsMigrator<InMemoryStorage>([
        SettingsMigration(1, (s) => ran.add('billing 1')),
      ], versionKey: 'billing_version');

      await profile.run(storage);
      await billing.run(storage);

      expect(ran, ['profile 1', 'profile 2', 'profile 3', 'billing 1']);
      expect((profile.currentVersion(storage), billing.currentVersion(storage)), (3, 1));
    });

    test('runs over one storage take turns, so a step is applied once', () async {
      final gate = Completer<void>();
      var applied = 0;
      final migrator = SettingsMigrator<InMemoryStorage>([
        SettingsMigration(1, (s) async {
          applied++;
          await gate.future;
        }),
      ], versionKey: _versionKey);

      final first = migrator.run(storage);
      final second = migrator.run(storage);
      gate.complete();

      expect(await first, 1);
      expect(await second, 0);
      expect(applied, 1);
    });

    test('rejects migrations that are not strictly ascending', () {
      expect(
        () => SettingsMigrator<InMemoryStorage>([
          SettingsMigration(2, (s) {}),
          SettingsMigration(2, (s) {}),
        ], versionKey: _versionKey),
        throwsArgumentError,
      );
      expect(
        () => SettingsMigrator<InMemoryStorage>([
          SettingsMigration(2, (s) {}),
          SettingsMigration(1, (s) {}),
        ], versionKey: _versionKey),
        throwsArgumentError,
      );
    });

    test('rejects a toVersion that is not positive, which run would skip', () {
      expect(
        () => SettingsMigrator<InMemoryStorage>([SettingsMigration(0, (s) {})], versionKey: _versionKey),
        throwsArgumentError,
      );
      expect(
        () => SettingsMigrator<InMemoryStorage>([SettingsMigration(-1, (s) {})], versionKey: _versionKey),
        throwsArgumentError,
      );
    });

    test('flushes the storage so migrated values reach the backend', () async {
      final dao = _MemoryDao();
      final cached = await CachedDaoStorage.create(dao: dao);
      final migrator = SettingsMigrator<CachedDaoStorage>([
        SettingsMigration(1, (s) => s.setString('k', 'v')),
      ], versionKey: _versionKey);

      await migrator.run(cached);

      expect(dao.rows['k'], 'sv');
      expect(dao.rows[_versionKey], 'i1');
    });

    test('a step may be asynchronous', () async {
      final migrator = SettingsMigrator<InMemoryStorage>([
        SettingsMigration(1, (s) async {
          final imported = await Future<int>.delayed(Duration.zero, () => 42);
          s.setInt('imported', imported);
        }),
        SettingsMigration(2, (s) => s.setInt('after', s.getInt('imported')! + 1)),
      ], versionKey: _versionKey);

      expect(await migrator.run(storage), 2);
      expect(storage.getInt('after'), 43, reason: 'step 2 ran after step 1 completed');
    });

    test("the version is persisted only after the step's data, never ahead of it", () async {
      final dao = _MemoryDao();
      final cached = await CachedDaoStorage.create(dao: dao);
      final migrator = SettingsMigrator<CachedDaoStorage>([
        SettingsMigration(1, (s) => s.setString('a', '1')),
        SettingsMigration(2, (s) => s.setString('b', '2')),
      ], versionKey: _versionKey);

      await migrator.run(cached);

      final order = dao.upsertOrder;
      expect(order.indexOf('a'), lessThan(order.indexOf('$_versionKey=i1')));
      expect(order.indexOf('$_versionKey=i1'), lessThan(order.indexOf('b')));
      expect(order.indexOf('b'), lessThan(order.indexOf('$_versionKey=i2')));
    });

    test('a write of a step that does not persist stops the run before the version is recorded', () async {
      final observer = RecordingObserver();
      final dao = _MemoryDao()..failKeys.add('a');
      final cached = await CachedDaoStorage.create(dao: dao, observer: observer);
      final migrator = SettingsMigrator<CachedDaoStorage>([
        SettingsMigration(1, (s) => s.setString('a', '1')),
        SettingsMigration(2, (s) => s.setString('b', '2')),
      ], versionKey: _versionKey);

      await expectLater(
        migrator.run(cached),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['a'])),
      );

      expect(dao.upsertOrder, ['a'], reason: 'neither the version nor the next step was written');
      expect(observer.events.single, isA<PersistErrorEvent>().having((e) => e.key, 'key', 'a'));
      await expectLater(cached.close(), throwsA(isA<SettingsPersistException>()), reason: '`a` is still unpersisted');
      final restarted = await CachedDaoStorage.create(dao: dao);
      expect(migrator.currentVersion(restarted), 0, reason: 'the step runs again on the next start');
    });

    test('a write that fails while an asynchronous step is still running stops the run as well', () async {
      final observer = RecordingObserver();
      final dao = _MemoryDao()..failKeys.add('a');
      final cached = await CachedDaoStorage.create(dao: dao, observer: observer);
      final migrator = SettingsMigrator<CachedDaoStorage>([
        SettingsMigration(1, (s) async {
          s.setString('a', '1');
          await Future<void>.delayed(Duration.zero);
          expect(observer.events, hasLength(1), reason: 'the write of `a` has failed before the step goes on');
          s.setString('b', '2');
        }),
      ], versionKey: _versionKey);

      await expectLater(
        migrator.run(cached),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['a'])),
      );

      expect(dao.rows, {'b': 's2'}, reason: 'the version was not recorded');
    });

    test('a version that does not persist stops the run before the next step', () async {
      final dao = _MemoryDao()..failKeys.add(_versionKey);
      final cached = await CachedDaoStorage.create(dao: dao, observer: RecordingObserver());
      var secondRan = false;
      final migrator = SettingsMigrator<CachedDaoStorage>([
        SettingsMigration(1, (s) => s.setString('a', '1')),
        SettingsMigration(2, (s) {
          secondRan = true;
        }),
      ], versionKey: _versionKey);

      await expectLater(
        migrator.run(cached),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', [_versionKey])),
      );

      expect(secondRan, isFalse);
      expect(dao.rows, {'a': 's1'});
    });

    test('a run in the same process persists a version an earlier run left in memory, then goes on', () async {
      final dao = _MemoryDao()..failKeys.add(_versionKey);
      final cached = await CachedDaoStorage.create(dao: dao, observer: RecordingObserver());
      var secondRuns = 0;
      final migrator = SettingsMigrator<CachedDaoStorage>([
        SettingsMigration(1, (s) => s.setString('a', '1')),
        SettingsMigration(2, (s) => secondRuns++),
      ], versionKey: _versionKey);
      await expectLater(migrator.run(cached), throwsA(isA<SettingsPersistException>()));
      expect(migrator.currentVersion(cached), 1, reason: 'the version is in memory, not in the backend');

      await expectLater(
        migrator.run(cached),
        throwsA(isA<SettingsPersistException>()),
        reason: 'the version still does not persist, so the run does not take step 1 for done',
      );
      expect(secondRuns, 0);

      dao.failKeys.clear();
      expect(await migrator.run(cached), 1);
      expect(dao.rows[_versionKey], 'i2');
      expect(secondRuns, 1);
    });

    test('a key left unpersisted before the run stops it as well', () async {
      final dao = _MemoryDao()..failKeys.add('earlier');
      final cached = await CachedDaoStorage.create(dao: dao, observer: RecordingObserver())
        ..setString('earlier', 'x');
      final migrator = SettingsMigrator<CachedDaoStorage>([
        SettingsMigration(1, (s) => s.setString('a', '1')),
      ], versionKey: _versionKey);

      await expectLater(
        migrator.run(cached),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['earlier'])),
      );

      expect(dao.rows, {'a': 's1'}, reason: 'the step ran, its version was not recorded');
    });

    test('a move that flushes before removing keeps the value when the write does not persist', () async {
      final dao = _MemoryDao()..rows['old_name'] = 'sBob';
      final cached = await CachedDaoStorage.create(dao: dao, observer: RecordingObserver());
      dao.failKeys.add('name');
      final migrator = SettingsMigrator<CachedDaoStorage>([
        SettingsMigration(1, (s) async {
          final name = s.getString('old_name');
          if (name == null) return;
          s.setString('name', name);
          await s.flush();
          s.remove('old_name');
        }),
      ], versionKey: _versionKey);

      await expectLater(migrator.run(cached), throwsA(isA<SettingsPersistException>()));
      expect(dao.rows, {'old_name': 'sBob'}, reason: 'the removal never ran');

      dao.failKeys.clear();
      await expectLater(
        cached.close(),
        throwsA(isA<SettingsPersistException>()),
        reason: '`name` is still unpersisted',
      );
      final restarted = await CachedDaoStorage.create(dao: dao);
      expect(await migrator.run(restarted), 1, reason: 'the step runs again and completes');
      expect(dao.rows, {'name': 'sBob', _versionKey: 'i1'});
    });
  });
}

final class _MemoryDao extends SettingsDao {
  final Map<String, String> rows = {};
  final List<String> upsertOrder = [];
  final Set<String> failKeys = {};

  @override
  Object get store => this;

  @override
  Future<void> deleteOne(String box, String key) async => rows.remove(key);

  @override
  Future<void> deleteByBox(String box) async => rows.clear();

  @override
  Future<List<SettingsRow>> getByBox(String box) async => [
    for (final e in rows.entries) SettingsRow(key: e.key, value: e.value),
  ];

  @override
  Future<void> upsert(String box, String key, String value) async {
    upsertOrder.add(key == _versionKey ? '$key=$value' : key);
    if (failKeys.contains(key)) throw StateError('disk full');
    rows[key] = value;
  }
}
