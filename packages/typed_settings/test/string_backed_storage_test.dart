import 'dart:async';

import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_backend.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

/// The minimum a string-only backend has to write: two async primitives and,
/// for box scoping, a key prefix.
final class PrefixedMemoryBackend extends StringBackedStorage {
  PrefixedMemoryBackend({required String prefix, Map<String, String> stored = const {}, super.observer})
    : super(cache: Map.of(stored), keyMapping: _Prefix(prefix)) {
    disk.addAll(stored);
  }

  @override
  Future<Map<String, String>> loadRaw() async => Map.of(disk);

  final Map<String, String> disk = {};
  final List<String> operations = [];

  @override
  Future<void> writeRaw(String key, String value) async {
    operations.add('write $key');
    disk[key] = value;
  }

  @override
  Future<void> deleteRaw(String key) async {
    operations.add('delete $key');
    disk.remove(key);
  }

  @override
  Future<void> writeBatchRaw(Map<String, String> upserts, Iterable<String> deletes) async {
    operations.add('batch upserts=[${upserts.keys.join(', ')}] deletes=[${deletes.join(', ')}]');
    disk.addAll(upserts);
    deletes.forEach(disk.remove);
  }
}

void main() {
  late PrefixedMemoryBackend storage;
  late RecordingObserver observer;

  setUp(() {
    observer = RecordingObserver();
    storage = PrefixedMemoryBackend(prefix: 'box.', observer: observer);
  });

  group('typed values', () {
    test('round-trip through the string representation and resolved keys', () async {
      storage
        ..setBool('b', true)
        ..setInt('i', -42)
        ..setDouble('d', 1.5)
        ..setString('s', 'text');
      await storage.flush();

      expect(storage.getBool('b'), isTrue);
      expect(storage.getInt('i'), -42);
      expect(storage.getDouble('d'), 1.5);
      expect(storage.getString('s'), 'text');
      expect(storage.disk, {
        'box.b': 'b1',
        'box.i': 'i-42',
        'box.d': 'd1.5',
        'box.s': 'stext',
      });
    });

    test('keys are setting keys, mapped back through the key mapping', () async {
      storage
        ..setInt('a', 1)
        ..setInt('b', 2);

      expect(storage.keys, ['a', 'b']);

      await storage.clear();
      expect(storage.keys, isEmpty);
    });

    test('undecodable strings are reported and read as absent', () async {
      storage.setString('k', 'garbage');

      expect(storage.getBool('k'), isNull);
      expect(storage.getInt('k'), isNull);
      expect(storage.getDouble('k'), isNull);
      expect(observer.events, hasLength(3));
      expect(
        observer.events,
        everyElement(
          isA<StorageReadErrorEvent>().having((e) => e.key, 'key', 'k').having((e) => e.raw, 'raw', 'garbage'),
        ),
      );
    });

    test('a string is not an int, and the null tag is not an explicit null', () {
      storage.setString('k', '5');
      expect(storage.getInt('k'), isNull);
      expect(storage.getString('k'), '5');
      expect(storage.hasNull('k'), isFalse);

      storage.setString('k', 'n');
      expect(storage.getString('k'), 'n');
      expect(storage.hasNull('k'), isFalse);

      storage.setString('k', '\u{E000}typed_settings:null');
      expect(storage.getString('k'), '\u{E000}typed_settings:null');
      expect(storage.hasNull('k'), isFalse);
    });

    test('an int is not readable as the string of its digits', () {
      storage.setInt('k', 5);

      expect(storage.getString('k'), isNull);
      expect(
        observer.events.single,
        isA<StorageReadErrorEvent>().having((e) => e.raw, 'raw', 5),
      );
    });
  });

  group('structured values', () {
    test('a MapSetting stores JSON text as a string', () async {
      final setting = MapSetting(storage: storage, key: 'm', defaultValue: const {});

      setting.value = {
        'a': 1,
        'nested': {'b': true},
      };
      await storage.flush();

      expect(storage.disk['box.m'], 's{"a":1,"nested":{"b":true}}');
      expect(storage.getString('m'), '{"a":1,"nested":{"b":true}}');
    });
  });

  group('explicit null and removal', () {
    test('setNull persists the marker, typed getters hide it, remove clears it', () async {
      storage.setInt('k', 1);
      storage.setNull('k');
      await storage.flush();

      expect(storage.hasNull('k'), isTrue);
      expect(storage.getInt('k'), isNull);
      expect(storage.getString('k'), isNull);
      expect(storage.disk['box.k'], 'n');

      storage.remove('k');
      await storage.flush();
      expect(storage.hasNull('k'), isFalse);
      expect(storage.disk, isEmpty);
    });

    test('clear deletes every key from cache and backend in one operation', () async {
      storage
        ..setInt('a', 1)
        ..setInt('b', 2);
      await storage.flush();
      storage.operations.clear();

      await storage.clear();

      expect(storage.getInt('a'), isNull);
      expect(storage.getInt('b'), isNull);
      expect(storage.disk, isEmpty);
      expect(storage.operations, ['batch upserts=[] deletes=[box.a, box.b]']);
    });

    test('clear is ordered after an in-flight write of the same key', () async {
      final gated = _GatedBackend();
      gated.setInt('a', 1); // in flight, held by the gate

      final clearing = gated.clear();
      gated.gate.complete();
      await clearing;

      expect(gated.disk, isEmpty, reason: 'the delete must run after the write it supersedes');
      expect(gated.getInt('a'), isNull);
    });
  });

  group('batch', () {
    test('the writes reach the backend as one writeBatchRaw with the final state of each key', () async {
      storage.setInt('gone', 1);
      await storage.flush();
      storage.operations.clear();

      storage.batch(() {
        storage
          ..setInt('a', 1)
          ..setInt('a', 2)
          ..setString('b', 'x')
          ..setNull('n')
          ..remove('gone');
      });
      expect(storage.operations, isEmpty, reason: 'nothing is persisted before the batch ends');
      await storage.flush();

      expect(storage.operations, ['batch upserts=[box.a, box.b, box.n] deletes=[box.gone]']);
      expect(storage.disk, {'box.a': 'i2', 'box.b': 'sx', 'box.n': 'n'});
    });

    test('each write notifies immediately, so a setting read inside the burst is current', () {
      var notified = 0;
      storage.addKeyListener('a', () => notified++);

      storage.batch(() {
        storage.setInt('a', 1);
        expect(storage.getInt('a'), 1);
        storage.setInt('a', 2);
      });

      expect(notified, 2);
    });

    test('an empty batch and a nested one persist when the outermost returns', () async {
      storage.batch(() {});
      storage.batch(() {
        storage.setInt('a', 1);
        storage.batch(() => storage.setInt('b', 2));
        storage.setNull('c');
      });
      await storage.flush();

      expect(storage.disk, {'box.a': 'i1', 'box.b': 'i2', 'box.c': 'n'});
    });

    test('the default writeBatchRaw falls back to per-key operations', () async {
      final plain = _GatedBackend()..gate.complete();
      plain.batch(() {
        plain
          ..setInt('a', 1)
          ..remove('b');
      });
      await plain.flush();

      expect(plain.disk, {'a': 'i1'});
    });

    test('is ordered after an in-flight write of one of its keys and before a later one', () async {
      final gated = _GatedBackend();
      gated.setInt('a', 1); // in flight, held
      gated.batch(() => gated.setInt('a', 2));
      gated.setInt('a', 3);

      gated.gate.complete();
      await gated.flush();

      expect(gated.log, ['write a=i1', 'write a=i2', 'write a=i3']);
      expect(gated.disk['a'], 'i3');
    });

    test('a failing batch is reported once per key', () async {
      final reported = RecordingObserver();
      final failing = _FailingBackend(observer: reported);

      failing.batch(() {
        failing
          ..setString('a', 'v')
          ..remove('b');
      });
      await expectLater(
        failing.flush(),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', unorderedEquals(['p.a', 'p.b']))),
      );

      expect(reported.events, hasLength(2));
      expect(reported.events.map((e) => e.key), unorderedEquals(['p.a', 'p.b']));
      expect(reported.events, everyElement(isA<PersistErrorEvent>()));
    });

    test('a clear inside the batch deletes what the batch wrote before it, in the backend too', () async {
      storage.setInt('old', 1);
      await storage.flush();
      late Future<void> clearing;

      storage.batch(() {
        storage.setInt('a', 1);
        clearing = storage.clear();
        storage.setInt('b', 2);
      });
      await clearing;

      expect(storage.disk, {'box.b': 'i2'});
    });

    test('a flush issued inside the batch covers its writes', () async {
      final holding = _HoldingBackend()..hold('a');
      var flushed = false;

      holding.batch(() {
        holding.setInt('a', 1);
        unawaited(holding.flush().then((_) => flushed = true));
      });
      await Future<void>.delayed(Duration.zero);
      expect(flushed, isFalse, reason: 'the batched write is still held');

      holding.release('a');
      await holding.flush();
      expect(flushed, isTrue);
      expect(holding.disk, {'a': 'i1'});
    });

    test('an exception inside the batch still persists the writes made so far', () async {
      expect(
        () => storage.batch(() {
          storage.setInt('a', 1);
          throw StateError('boom');
        }),
        throwsStateError,
      );
      await storage.flush();

      expect(storage.disk['box.a'], 'i1');
    });
  });

  group('BackgroundPersistence', () {
    test('flush waits for the writes issued before it, not for a key written afterwards', () async {
      final holding = _HoldingBackend();
      holding.hold('a');
      holding.hold('b');
      holding.setInt('a', 1); // in flight, held

      var flushed = false;
      final flushing = holding.flush().then((_) => flushed = true);
      holding.setInt('b', 1); // issued after flush: in flight, held, and not waited for

      holding.release('a');
      await flushing;

      expect(flushed, isTrue, reason: 'a write issued after flush must not delay it');
      expect(holding.disk, {'a': 'i1'});

      holding.release('b');
      await holding.flush();
      expect(holding.disk, {'a': 'i1', 'b': 'i1'});
    });

    test('a flush scoped to keys does not wait for a slow write of another key', () async {
      final holding = _HoldingBackend()..hold('slow');
      holding
        ..setInt('slow', 1)
        ..setInt('fast', 2);

      await holding.flush(keys: ['other']);
      expect(holding.disk, isEmpty, reason: 'the slow write holds the queue at one operation at a time');

      holding.release('slow');
      await holding.flush(keys: ['fast']);
      expect(holding.disk, {'slow': 'i1', 'fast': 'i2'});
    });

    test('a backend that allows it writes distinct keys at once, so a slow one holds no other back', () async {
      final holding = _HoldingBackend(maxConcurrent: 2)..hold('slow');
      holding
        ..setInt('slow', 1)
        ..setInt('fast', 2);

      await holding.flush(keys: ['fast']);
      expect(holding.disk, {'fast': 'i2'});

      holding.release('slow');
      await holding.flush();
      expect(holding.disk, {'fast': 'i2', 'slow': 'i1'});
    });

    test('persist failures reach the observer with the resolved key', () async {
      final reported = RecordingObserver();
      final failing = _FailingBackend(observer: reported);

      failing.setString('k', 'v');
      await expectLater(
        failing.flush(),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['p.k'])),
      );

      expect(reported.events.single, isA<PersistErrorEvent>().having((e) => e.key, 'key', 'p.k'));
      expect(failing.getString('k'), 'v', reason: 'cache keeps the value; the failure is reported, not rolled back');
    });

    test('a flush scoped to setting keys finds them under the resolved keys', () async {
      final failing = _FailingBackend(observer: RecordingObserver());
      failing.setString('k', 'v');

      await expectLater(
        failing.flush(keys: ['k']),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['p.k'])),
      );
      await failing.flush(keys: ['other']);
    });

    test('a tracked bulk operation over every key persists the keys that failed before it', () async {
      final reported = <PersistErrorEvent>[];
      final persistence = BackgroundPersistence(report: reported.add);
      persistence.track(const PersistTarget.key('a'), Future<void>.error(StateError('disk full')));
      await expectLater(
        persistence.flush(),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['a'])),
      );

      persistence.track(const PersistTarget.all('box'), Future<void>.error(StateError('disk full')));
      await expectLater(
        persistence.flush(),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', unorderedEquals(['a', 'box']))),
      );

      persistence.track(const PersistTarget.all('box'), Future<void>.value());
      await persistence.flush();
      expect(reported.map((event) => event.key), ['a', 'box']);
    });

    test('a tracked operation over several keys leaves each of them out of date until one persists it', () async {
      final persistence = BackgroundPersistence(report: (_) {});
      persistence.track(PersistTarget.keys(const ['a', 'b']), Future<void>.error(StateError('disk full')));
      await expectLater(
        persistence.flush(),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', unorderedEquals(['a', 'b']))),
      );

      persistence.track(const PersistTarget.key('a'), Future<void>.value());
      await expectLater(
        persistence.flush(),
        throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['b'])),
      );
      await persistence.flush(keys: ['a']);
    });

    test('rejects fewer than one concurrent operation when created', () {
      expect(() => BackgroundPersistence(report: (_) {}, maxConcurrentOperations: 0), throwsArgumentError);
    });

    test('a clear that deletes a key whose write failed persists it again', () async {
      final flaky = _FlakyBackend(observer: RecordingObserver())..failing = true;
      flaky.setString('k', 'v');
      await expectLater(flaky.flush(), throwsA(isA<SettingsPersistException>()));

      flaky.failing = false;
      await flaky.clear();
      expect(flaky.disk, isEmpty);
    });
  });

  group('a backend shared with other storages, loaded whole', () {
    late PrefixedMemoryBackend backend;

    setUp(() {
      backend = PrefixedMemoryBackend(
        prefix: 'p.',
        stored: {'p.mine': encodeStoredInt(1), 'q.theirs': encodeStoredString('secret')},
        observer: RecordingObserver(),
      );
    });

    test('lists and reads its own keys only', () {
      expect(backend.keys, ['mine']);
      expect(backend.getInt('mine'), 1);
    });

    test('clear removes its own keys and leaves the others in the backend', () async {
      await backend.clear();

      expect(backend.keys, isEmpty);
      expect(backend.disk, {'q.theirs': encodeStoredString('secret')});
    });

    test('clear inside a batch leaves the others too', () async {
      late Future<void> cleared;
      backend.batch(() => cleared = backend.clear());
      await cleared;

      expect(backend.disk, {'q.theirs': encodeStoredString('secret')});
    });
  });

  group('reload', () {
    test('a key whose write failed reads what the backend holds, and flush no longer fails for it', () async {
      final flaky = _FlakyBackend(observer: RecordingObserver())..setInt('k', 1);
      await flaky.flush();
      flaky
        ..failing = true
        ..setInt('k', 2)
        ..setInt('new', 3);
      await expectLater(flaky.flush(), throwsA(isA<SettingsPersistException>()));
      final notified = <String>[];
      flaky
        ..addKeyListener('k', () => notified.add('k'))
        ..addKeyListener('new', () => notified.add('new'));

      await flaky.reload();

      expect(flaky.getInt('k'), 1, reason: 'the backend never held 2');
      expect(flaky.getInt('new'), isNull);
      expect(notified, unorderedEquals(['k', 'new']));
      await flaky.flush();
    });

    test('a failed clear is undone: the keys the backend still holds read again', () async {
      final flaky = _FlakyBackend(observer: RecordingObserver())..setInt('k', 1);
      await flaky.flush();
      flaky.failing = true;
      await expectLater(flaky.clear(), throwsA(isA<SettingsPersistException>()));
      expect(flaky.getInt('k'), isNull);

      await flaky.reload();

      expect(flaky.getInt('k'), 1);
      await flaky.flush();
    });

    test('a key whose write fails while the reload runs stays out of date', () async {
      final flaky = _FlakyBackend(observer: RecordingObserver())..failing = true;

      final reloading = flaky.reload();
      flaky.setInt('k', 1);
      await reloading;

      expect(flaky.getInt('k'), 1);
      await expectLater(flaky.flush(), throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['k'])));
    });

    test('fails with what the backend throws and leaves the state as it was', () async {
      final flaky = _FlakyBackend(observer: RecordingObserver())..setInt('k', 1);
      await flaky.flush();
      flaky
        ..disk['k'] = encodeStoredInt(2)
        ..failingLoad = true;
      var notified = 0;
      flaky.addKeyListener('k', () => notified++);

      await expectLater(flaky.reload(), throwsStateError);

      expect(flaky.getInt('k'), 1);
      expect(notified, 0);

      flaky.failingLoad = false;
      await flaky.reload();
      expect(flaky.getInt('k'), 2, reason: 'a failed reload does not block the next one');
    });

    test('waits for the writes of an open batch and keeps them', () async {
      final backend = PrefixedMemoryBackend(prefix: 'p.');
      late Future<void> reloading;

      backend.batch(() {
        reloading = backend.reload();
        backend.setInt('k', 1);
      });
      await reloading;
      await backend.flush();

      expect(backend.getInt('k'), 1);
      expect(backend.disk, {'p.k': encodeStoredInt(1)});
    });

    test('leaves out the keys of another storage that shares the backend', () async {
      final backend = PrefixedMemoryBackend(prefix: 'p.');
      backend.disk
        ..['p.mine'] = encodeStoredInt(1)
        ..['q.theirs'] = encodeStoredInt(2);

      await backend.reload();

      expect(backend.keys, ['mine']);
      await backend.clear();
      expect(backend.disk, {'q.theirs': encodeStoredInt(2)});
    });
  });
}

/// Holds the first write until [gate] completes; later operations run freely.
final class _GatedBackend extends StringBackedStorage {
  _GatedBackend() : super(cache: {});

  @override
  Future<Map<String, String>> loadRaw() async => Map.of(disk);

  final Map<String, String> disk = {};
  final List<String> log = [];
  final Completer<void> gate = Completer<void>();
  var _held = false;

  @override
  Future<void> writeRaw(String key, String value) async {
    if (!_held) {
      _held = true;
      await gate.future;
    }
    log.add('write $key=$value');
    disk[key] = value;
  }

  @override
  Future<void> deleteRaw(String key) async => disk.remove(key);
}

/// Holds the writes of the keys given to [hold] until [release]d; other
/// keys write immediately.
final class _HoldingBackend extends StringBackedStorage {
  _HoldingBackend({int maxConcurrent = 1}) : super(cache: {}, maxConcurrentOperations: maxConcurrent);

  @override
  Future<Map<String, String>> loadRaw() async => Map.of(disk);

  final Map<String, String> disk = {};
  final Map<String, Completer<void>> _holds = {};

  void hold(String key) => _holds[key] = Completer<void>();

  void release(String key) => _holds.remove(key)!.complete();

  @override
  Future<void> writeRaw(String key, String value) async {
    final hold = _holds[key];
    if (hold != null) await hold.future;
    disk[key] = value;
  }

  @override
  Future<void> deleteRaw(String key) async => disk.remove(key);
}

/// Fails every write and removal while [failing] is set.
final class _FlakyBackend extends StringBackedStorage {
  _FlakyBackend({super.observer}) : super(cache: {});

  @override
  Future<Map<String, String>> loadRaw() async {
    if (failingLoad) throw StateError('unreadable');
    return Map.of(disk);
  }

  bool failing = false;
  bool failingLoad = false;
  final Map<String, String> disk = {};

  @override
  Future<void> writeRaw(String key, String value) async {
    if (failing) throw StateError('disk full');
    disk[key] = value;
  }

  @override
  Future<void> deleteRaw(String key) async {
    if (failing) throw StateError('disk full');
    disk.remove(key);
  }
}

/// Stores every setting key behind [prefix].
class _Prefix implements KeyMapping {
  const _Prefix(this.prefix);

  final String prefix;

  @override
  String storedKey(String key) => '$prefix$key';

  @override
  String? settingKey(String storedKey) => storedKey.startsWith(prefix) ? storedKey.substring(prefix.length) : null;
}

final class _FailingBackend extends StringBackedStorage {
  _FailingBackend({super.observer}) : super(cache: {}, keyMapping: const _Prefix('p.'));

  @override
  Future<Map<String, String>> loadRaw() async => {};

  @override
  Future<void> writeRaw(String key, String value) async => throw StateError('disk full');

  @override
  Future<void> deleteRaw(String key) async => throw StateError('disk full');
}
