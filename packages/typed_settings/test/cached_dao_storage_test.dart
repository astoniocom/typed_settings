import 'dart:async';

import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_dao.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

import 'package:typed_settings_conformance/typed_settings_conformance.dart';

/// [SettingsDao] whose operations can be delayed (via [gate]) or forced to
/// fail (via [failWith]).
base class FakeDao extends SettingsDao {
  final Map<String, String> rows = {};

  /// When set, write operations do not complete until the gate completes.
  Completer<void>? gate;

  /// When set, write operations throw this error.
  Error? failWith;

  int concurrency = 1;

  @override
  Object get store => this;

  @override
  int get maxConcurrentOperations => concurrency;

  Future<void> _write(void Function() apply) async {
    final gate = this.gate;
    if (gate != null) await gate.future;
    final failure = failWith;
    if (failure != null) throw failure;
    apply();
  }

  @override
  Future<List<SettingsRow>> getByBox(String box) async => [
    for (final entry in rows.entries) SettingsRow(key: entry.key, value: entry.value),
  ];

  @override
  Future<void> upsert(String box, String key, String value) => _write(() => rows[key] = value);

  @override
  Future<void> deleteOne(String box, String key) => _write(() => rows.remove(key));

  int deleteByBoxCalls = 0;

  @override
  Future<void> deleteByBox(String box) => _write(() {
    deleteByBoxCalls++;
    rows.clear();
  });

  final List<({Map<String, String> upserts, List<String> deletes})> batches = [];

  @override
  Future<void> writeBatch(String box, {required Map<String, String> upserts, required Iterable<String> deletes}) =>
      _write(() {
        batches.add((upserts: Map.of(upserts), deletes: List.of(deletes)));
        rows.addAll(upserts);
        deletes.forEach(rows.remove);
      });
}

void main() {
  group('CachedDaoStorage.clear', () {
    test('issues one deleteByBox instead of a delete per key', () async {
      final dao = FakeDao();
      final storage = await CachedDaoStorage.create(dao: dao)
        ..setInt('a', 1)
        ..setInt('b', 2)
        ..setString('c', 'x');
      await storage.flush();

      await storage.clear();

      expect(dao.deleteByBoxCalls, 1);
      expect(dao.rows, isEmpty);
      expect(storage.getInt('a'), isNull);
    });

    test('a pending write from before clear cannot resurrect its key, a write after clear survives', () async {
      final dao = FakeDao();
      final storage = await CachedDaoStorage.create(dao: dao);
      final gate = Completer<void>();
      dao.gate = gate;
      storage.setInt('old', 1); // in flight, blocked
      dao.gate = null;

      final clearing = storage.clear();
      storage.setInt('fresh', 2); // issued after clear

      gate.complete();
      await clearing;
      await storage.flush();

      expect(dao.rows, {'fresh': 'i2'});
      expect(storage.getInt('old'), isNull);
      expect(storage.getInt('fresh'), 2);
    });

    test('inside a batch, the writes the batch made before it do not reach the dao after it', () async {
      final dao = FakeDao()..rows['old'] = '1';
      final storage = await CachedDaoStorage.create(dao: dao);
      late Future<void> clearing;

      storage.batch(() {
        storage.setInt('a', 1);
        clearing = storage.clear();
        storage.setInt('b', 2);
      });
      await clearing;

      expect(dao.rows, {'b': 'i2'});
      await storage.close();
      final reloaded = await CachedDaoStorage.create(dao: dao);
      expect(reloaded.getInt('a'), isNull, reason: 'a cleared write must not come back after a restart');
      expect(reloaded.getInt('b'), 2);
    });
  });

  group('CachedDaoStorage.batch', () {
    test('hands the writes to the dao as one writeBatch, including through settings', () async {
      final dao = FakeDao()..rows['gone'] = 'x';
      final storage = await CachedDaoStorage.create(dao: dao);
      final count = IntSetting(storage: storage, key: 'count', defaultValue: 0);
      final name = StringSetting(storage: storage, key: 'name', defaultValue: '');

      storage.batch(() {
        count.value = 5;
        name.value = 'alice';
        count.value = 6;
        storage.remove('gone');
      });
      await storage.flush();

      expect(dao.batches, hasLength(1));
      expect(dao.batches.single.upserts, {'count': 'i6', 'name': 'salice'});
      expect(dao.batches.single.deletes, ['gone']);
      expect(dao.rows, {'count': 'i6', 'name': 'salice'});
    });

    test('a failing batch reports every key of the batch and leaves them all unpersisted', () async {
      final dao = FakeDao()..failWith = StateError('disk full');
      final observer = RecordingObserver();
      final storage = await CachedDaoStorage.create(dao: dao, observer: observer);

      storage.batch(() {
        storage
          ..setInt('a', 1)
          ..setInt('b', 2);
      });
      await expectLater(
        storage.flush(),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', unorderedEquals(['a', 'b']))),
      );

      expect(observer.events.map((e) => e.key), unorderedEquals(['a', 'b']));
      expect(observer.events, everyElement(isA<PersistErrorEvent>()));
    });
  });

  group('CachedDaoStorage write ordering', () {
    test('a slow first write cannot overwrite a later one on disk', () async {
      final dao = FakeDao();
      final storage = await CachedDaoStorage.create(dao: dao);

      final firstGate = Completer<void>();
      dao.gate = firstGate;
      storage.setString('k', 'first');
      dao.gate = null; // the second write would complete immediately if it ran now
      storage.setString('k', 'second');

      await Future<void>.delayed(Duration.zero);
      expect(dao.rows, isEmpty, reason: 'second write must wait for the first');

      firstGate.complete();
      await storage.flush();

      expect(dao.rows['k'], 'ssecond');
      expect(storage.getString('k'), 'second');
    });
  });

  group('CachedDaoStorage.flush', () {
    test('completes only after pending writes reach the dao', () async {
      final dao = FakeDao();
      final storage = await CachedDaoStorage.create(dao: dao);

      dao.gate = Completer<void>();
      storage.setInt('k', 42);
      expect(dao.rows, isEmpty, reason: 'write is gated');

      var flushed = false;
      final flush = storage.flush().then((_) => flushed = true);
      await Future<void>.delayed(Duration.zero);
      expect(flushed, isFalse, reason: 'flush must wait for the gated write');

      dao.gate!.complete();
      await flush;
      expect(dao.rows['k'], 'i42');
    });

    test('covers removals too', () async {
      final dao = FakeDao()..rows['k'] = '1';
      final storage = await CachedDaoStorage.create(dao: dao);

      storage.remove('k');
      await storage.flush();

      expect(dao.rows, isEmpty);
    });
  });

  group('CachedDaoStorage.getBool', () {
    test('parses only true/false and reports garbage as missing', () async {
      final dao = FakeDao()
        ..rows['t'] = 'b1'
        ..rows['f'] = 'b0'
        ..rows['word'] = 'true'
        ..rows['garbage'] = '1';
      final observer = RecordingObserver();
      final storage = await CachedDaoStorage.create(dao: dao, observer: observer);

      expect(storage.getBool('t'), isTrue);
      expect(storage.getBool('f'), isFalse);
      expect(storage.getBool('word'), isNull, reason: 'the word true is a string, not a bool');
      expect(storage.getBool('garbage'), isNull, reason: 'corrupted value must not silently become false');
      expect(storage.getBool('absent'), isNull);
      expect(observer.events, hasLength(2));
      expect(
        observer.events,
        containsAll([
          isA<StorageReadErrorEvent>().having((e) => e.key, 'key', 'word').having((e) => e.raw, 'raw', 'true'),
          isA<StorageReadErrorEvent>().having((e) => e.key, 'key', 'garbage').having((e) => e.raw, 'raw', '1'),
        ]),
      );
    });
  });

  group('CachedDaoStorage explicit null', () {
    test('is distinct from absence and hides the marker from typed getters', () async {
      final storage = await CachedDaoStorage.create(dao: FakeDao());

      expect(storage.hasNull('k'), isFalse, reason: 'absent key');

      storage.setInt('k', 1);
      expect(storage.hasNull('k'), isFalse, reason: 'typed value');

      storage.setNull('k');
      expect(storage.hasNull('k'), isTrue);
      expect(storage.getInt('k'), isNull);
      expect(storage.getString('k'), isNull);
      expect(storage.getBool('k'), isNull);
      expect(storage.getDouble('k'), isNull);

      storage.setString('k', 'v');
      expect(storage.hasNull('k'), isFalse, reason: 'typed write replaces the null');

      storage
        ..setNull('k')
        ..remove('k');
      expect(storage.hasNull('k'), isFalse, reason: 'remove clears the null too');
    });

    test('survives a round trip through the dao', () async {
      final dao = FakeDao();
      final storage = await CachedDaoStorage.create(dao: dao);
      storage.setNull('k');
      await storage.close();

      final reloaded = await CachedDaoStorage.create(dao: dao);
      expect(reloaded.hasNull('k'), isTrue);
      expect(reloaded.getString('k'), isNull);
    });
  });

  group('CachedDaoStorage lifecycle', () {
    test('one open storage per box of a dao; another box or another dao is free', () async {
      final dao = FakeDao();
      await CachedDaoStorage.create(dao: dao, box: 'a');

      await expectLater(CachedDaoStorage.create(dao: dao, box: 'a'), throwsStateError);
      await CachedDaoStorage.create(dao: dao, box: 'b');
      await CachedDaoStorage.create(dao: FakeDao(), box: 'a');
    });

    test('a storage that could not be created does not hold its box', () async {
      final dao = FakeDao()..concurrency = 0;
      await expectLater(CachedDaoStorage.create(dao: dao, box: 'a'), throwsArgumentError);

      dao.concurrency = 1;
      await CachedDaoStorage.create(dao: dao, box: 'a');
    });

    test('two dao objects that name one store share its boxes', () async {
      await CachedDaoStorage.create(dao: _TableDao('settings'), box: 'a');

      await expectLater(CachedDaoStorage.create(dao: _TableDao('settings'), box: 'a'), throwsStateError);
      await CachedDaoStorage.create(dao: _TableDao('settings'), box: 'b');
      await CachedDaoStorage.create(dao: _TableDao('other'), box: 'a');
    });

    test('a storage dropped without close does not keep its dao alive', () async {
      final dropped = await _daoUnderUnclosedStorage();

      expect(await _isCollected(dropped), isTrue, reason: 'the list of served boxes must not hold the backend');
    }, testOn: 'vm');

    test('close fails like flush for a write that did not persist, and releases the box all the same', () async {
      final dao = FakeDao()..failWith = StateError('disk full');
      final storage = await CachedDaoStorage.create(dao: dao, observer: RecordingObserver())
        ..setInt('k', 1);

      await expectLater(storage.close(), throwsA(isA<SettingsPersistException>()));

      dao.failWith = null;
      final reopened = await CachedDaoStorage.create(dao: dao);
      expect(reopened.getInt('k'), isNull, reason: 'the write never reached the dao');
    });

    test('a setting over a closed storage throws, and none can be created over it', () async {
      final storage = await CachedDaoStorage.create(dao: FakeDao());
      final setting = IntSetting(storage: storage, key: 'k', defaultValue: 0);
      await storage.close();

      expect(() => setting.value, throwsStateError);
      expect(() => setting.value = 1, throwsStateError);
      expect(() => IntSetting(storage: storage, key: 'other', defaultValue: 0), throwsStateError);
      expect(SettingsRegistry.of(storage)['k'], same(setting), reason: 'the rejected setting left nothing behind');
      setting.dispose();
    });
  });

  group('InMemoryStorage explicit null', () {
    test('is distinct from absence and cleared by remove', () {
      final storage = InMemoryStorage();
      expect(storage.hasNull('k'), isFalse);

      storage.setNull('k');
      expect(storage.hasNull('k'), isTrue);
      expect(storage.getInt('k'), isNull);

      storage.setInt('k', 1);
      expect(storage.hasNull('k'), isFalse);

      storage
        ..setNull('k')
        ..remove('k');
      expect(storage.hasNull('k'), isFalse);
    });
  });

  group('CachedDaoStorage persist errors', () {
    test('are delivered to the observer as PersistErrorEvent with the failing key', () async {
      final dao = FakeDao()..failWith = StateError('disk full');
      final observer = RecordingObserver();
      final storage = await CachedDaoStorage.create(dao: dao, observer: observer);

      storage.setString('k', 'v');
      await expectLater(storage.flush(), throwsA(isA<SettingsPersistException>()));

      final event = observer.events.single;
      expect(
        event,
        isA<PersistErrorEvent>().having((e) => e.key, 'key', 'k').having((e) => e.error, 'error', isA<StateError>()),
      );
      expect(event.message, allOf(contains('`k`'), contains('disk full')));
      // The documented divergence: the cache keeps the value even though
      // persistence failed.
      expect(storage.getString('k'), 'v');
      expect(dao.rows, isEmpty);
    });

    test('a write that did not persist is reported to the observer as a PersistErrorEvent', () async {
      final dao = FakeDao()..failWith = StateError('disk full');
      final persistErrors = <PersistErrorEvent>[];
      final storage = await CachedDaoStorage.create(dao: dao, observer: _PersistOnlyObserver(persistErrors));

      storage.setString('k', 'v');
      await expectLater(storage.flush(), throwsA(isA<SettingsPersistException>()));

      expect(persistErrors.single.key, 'k');
    });
  });

  group('CachedDaoStorage.flush after a failure', () {
    late FakeDao dao;
    late RecordingObserver observer;
    late CachedDaoStorage storage;

    setUp(() async {
      dao = FakeDao();
      observer = RecordingObserver();
      storage = await CachedDaoStorage.create(dao: dao, box: 'settings', observer: observer);
    });

    Matcher notPersisted(Object keys) => throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', keys));

    test('the exception needs at least one failure', () {
      expect(() => SettingsPersistException(const []), throwsArgumentError);
    });

    test('fails with the keys that did not persist, carrying the failures reported to the observer', () async {
      dao.failWith = StateError('disk full');
      storage
        ..setString('a', '1')
        ..setString('b', '2');

      await expectLater(storage.flush(), notPersisted(unorderedEquals(['a', 'b'])));
      await expectLater(
        storage.flush(),
        throwsA(
          isA<SettingsPersistException>().having((e) => e.failures, 'failures', unorderedEquals(observer.events)),
        ),
      );
    });

    test('keeps failing until a later write or removal of each key persists', () async {
      dao.failWith = StateError('disk full');
      storage
        ..setString('a', '1')
        ..setString('b', '2');
      await expectLater(storage.flush(), notPersisted(unorderedEquals(['a', 'b'])));

      dao.failWith = null;
      storage.setString('a', '1');
      await expectLater(storage.flush(), notPersisted(['b']));

      storage.remove('b');
      await storage.flush();
      expect(dao.rows, {'a': 's1'});
    });

    test('reports a failure that happened before the call, with nothing pending any more', () async {
      dao.failWith = StateError('disk full');
      storage.setString('a', '1');
      await Future<void>.delayed(Duration.zero);
      expect(observer.events, hasLength(1), reason: 'the write has failed already');

      await expectLater(storage.flush(), notPersisted(['a']));
    });

    test('leaves out a key that is out of date only because of a write issued after the call', () async {
      final gate = Completer<void>();
      dao
        ..gate = gate
        ..failWith = StateError('disk full');
      storage.setString('a', '1');
      final flushing = storage.flush();
      storage.setString('b', '2');
      gate.complete();

      await expectLater(flushing, notPersisted(['a']));
      await expectLater(storage.flush(), notPersisted(unorderedEquals(['a', 'b'])));
    });

    test('a clear that empties the box persists every key again', () async {
      dao.failWith = StateError('disk full');
      storage.setString('a', '1');
      await expectLater(storage.flush(), notPersisted(['a']));

      dao.failWith = null;
      await storage.clear();
      await storage.flush();
    });

    test('a clear that does not persist fails, named after the box', () async {
      storage.setString('a', '1');
      await storage.flush();

      dao.failWith = StateError('disk full');
      await expectLater(storage.clear(), notPersisted(['settings']));
    });

    test('scoped to keys, fails only for those of them that are out of date', () async {
      dao.failWith = StateError('disk full');
      storage
        ..setString('a', '1')
        ..setString('b', '2');

      await expectLater(storage.flush(keys: ['a']), notPersisted(['a']));
      await expectLater(storage.flush(keys: ['a', 'b', 'c']), notPersisted(unorderedEquals(['a', 'b'])));

      dao.failWith = null;
      storage.setString('a', '1');
      await storage.flush(keys: ['a', 'c']);
      await expectLater(storage.flush(), notPersisted(['b']));
    });

    test(
      'scoped to keys, counts a key as out of date after a clear that did not persist, until it is persisted again',
      () async {
        storage
          ..setString('a', '1')
          ..setString('b', '2');
        await storage.flush();

        dao.failWith = StateError('disk full');
        await expectLater(storage.clear(), notPersisted(['settings']));
        await expectLater(
          storage.flush(keys: ['a']),
          notPersisted(['settings']),
          reason: 'the backend may still hold the old `a`',
        );

        dao.failWith = null;
        storage.setString('a', '3');
        await storage.flush(keys: ['a']);
        await expectLater(storage.flush(keys: ['b']), notPersisted(['settings']));
      },
    );
  });
}

/// A DAO nothing references any more, except an unclosed storage over it
/// that nothing references either. Created in a function of its own so
/// that no local of the test keeps it alive.
Future<WeakReference<Object>> _daoUnderUnclosedStorage() async {
  final dao = FakeDao();
  final storage = await CachedDaoStorage.create(dao: dao, box: 'user');
  storage.setInt('age', 1);
  await storage.flush();
  return WeakReference(dao);
}

Future<bool> _isCollected(WeakReference<Object> reference) async {
  for (var round = 0; round < 50 && reference.target != null; round++) {
    final garbage = <List<int>>[];
    for (var i = 0; i < 200; i++) {
      garbage.add(List.filled(100000, i));
      if (garbage.length > 20) garbage.clear();
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  return reference.target == null;
}

/// A DAO over the table [table]; every DAO object over one table names the
/// same store.
final class _TableDao extends FakeDao {
  _TableDao(this.table);

  final String table;

  @override
  Object get store => ('table', table);
}

final class _PersistOnlyObserver extends SettingsObserver {
  const _PersistOnlyObserver(this.sink);

  final List<PersistErrorEvent> sink;

  @override
  void onEvent(SettingsEvent event) {
    if (event is PersistErrorEvent) sink.add(event);
  }
}
