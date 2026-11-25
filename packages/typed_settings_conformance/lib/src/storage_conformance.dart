import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_conformance/src/recording_observer.dart';

/// Registers the contract every [SettingsStorage] implementation
/// must satisfy as a test group named after [name].
///
/// [create] builds a fresh, empty storage for each test and must attach
/// the given observer to it, so that the suite can assert on diagnostics.
/// Call it from a backend package's test `main`:
///
/// ```dart
/// void main() {
///   storageConformance('MyStorage', (observer) async => MyStorage(observer: observer));
/// }
/// ```
///
/// Pass [writeOutside] for a backend that something other than the storage
/// can write to, so that the suite checks `reload` against such writes.
/// Without it the suite only checks that `reload` leaves a storage alone
/// whose backend nothing else wrote.
void storageConformance(
  String name,
  Future<SettingsStorage> Function(SettingsObserver observer) create, {
  OutsideWrite? writeOutside,
}) {
  group('$name conformance', () {
    late RecordingObserver observer;
    late SettingsStorage storage;

    setUp(() async {
      observer = RecordingObserver();
      storage = await create(observer);
    });

    test('absent keys read as null as every type and are not explicit nulls', () {
      expect(storage.getBool('k'), isNull);
      expect(storage.getInt('k'), isNull);
      expect(storage.getDouble('k'), isNull);
      expect(storage.getString('k'), isNull);
      expect(storage.hasNull('k'), isFalse);
    });

    test('each type round-trips, including edge values', () async {
      storage
        ..setBool('b', false)
        ..setInt('i', -9007199254740991)
        ..setDouble('d', double.negativeInfinity)
        ..setDouble('nan', double.nan)
        ..setString('s', '')
        ..setString('u', 'ünïcödé \u{1F600} \n tab\t');
      await storage.flush();

      expect(storage.getBool('b'), isFalse);
      expect(storage.getInt('i'), -9007199254740991);
      expect(storage.getDouble('d'), double.negativeInfinity);
      expect(storage.getDouble('nan'), isNaN);
      expect(storage.getString('s'), '');
      expect(storage.getString('u'), 'ünïcödé \u{1F600} \n tab\t');
    });

    test(
      'consecutive mutations of one key take effect in memory immediately, while earlier ones still persist',
      () async {
        storage
          ..setInt('k', 1)
          ..setInt('k', 2);
        expect(storage.getInt('k'), 2);

        storage.remove('k');
        expect(storage.getInt('k'), isNull);

        storage
          ..setString('k', 'a')
          ..setNull('k');
        expect(storage.hasNull('k'), isTrue);

        await storage.flush();
        expect(storage.hasNull('k'), isTrue, reason: 'the last mutation is what persists');
      },
    );

    test('a write replaces a value of another type under the same key', () async {
      storage.setInt('k', 1);
      storage.setString('k', 'text');
      await storage.flush();

      expect(storage.getString('k'), 'text');
    });

    test('a value that cannot be read as the requested type is reported and reads as absent', () async {
      storage.setString('k', 'text');
      await storage.flush();

      expect(storage.getInt('k'), isNull);
      expect(storage.getDouble('k'), isNull);
      expect(storage.getBool('k'), isNull);
      expect(storage.hasNull('k'), isFalse);
      expect(storage.getString('k'), 'text', reason: 'the value itself is untouched');

      expect(observer.events, hasLength(3));
      for (final event in observer.events) {
        expect(
          event,
          isA<StorageReadErrorEvent>().having((e) => e.key, 'key', 'k').having((e) => e.raw, 'raw', 'text'),
        );
      }
    });

    test('a setting over a mismatched value falls back to its default without a setting-level event', () async {
      storage.setString('k', 'text');
      await storage.flush();

      final setting = IntSetting(storage: storage, key: 'k', defaultValue: 7);
      expect(setting.value, 7);
      expect(observer.events.single, isA<StorageReadErrorEvent>());
    });

    test('remove makes a key absent again', () async {
      storage.setInt('k', 1);
      storage.remove('k');
      await storage.flush();

      expect(storage.getInt('k'), isNull);
      expect(storage.hasNull('k'), isFalse);
    });

    test('explicit null is a third state, hidden from typed getters', () async {
      storage.setInt('k', 1);
      storage.setNull('k');
      await storage.flush();

      expect(storage.hasNull('k'), isTrue);
      expect(storage.getInt('k'), isNull);
      expect(storage.getString('k'), isNull);

      storage.setString('k', 'v');
      expect(storage.hasNull('k'), isFalse, reason: 'a typed write replaces the null');

      storage
        ..setNull('k')
        ..remove('k');
      await storage.flush();
      expect(storage.hasNull('k'), isFalse, reason: 'remove clears the null too');
    });

    test('clear removes every key and persists', () async {
      storage
        ..setInt('a', 1)
        ..setNull('b')
        ..setString('c', 'x');

      await storage.clear();

      expect(storage.getInt('a'), isNull);
      expect(storage.hasNull('b'), isFalse);
      expect(storage.getString('c'), isNull);
    });

    test('clear updates the in-memory state synchronously, like every other mutator', () async {
      storage
        ..setInt('a', 1)
        ..setNull('b');
      int? seenByListener;
      var listenerCalls = 0;
      storage.addKeyListener('a', () {
        listenerCalls++;
        seenByListener = storage.getInt('a');
      });

      final done = storage.clear();

      expect(storage.getInt('a'), isNull, reason: 'cleared before the future completes');
      expect(storage.hasNull('b'), isFalse);
      expect(listenerCalls, 1, reason: 'notified synchronously');
      expect(seenByListener, isNull, reason: 'the listener already sees the cleared state');
      await done;
      expect(storage.getInt('a'), isNull);
    });

    test('a write issued right after clear is not wiped by it', () async {
      storage.setInt('a', 1);
      final cleared = storage.clear();
      storage.setInt('a', 2);
      await cleared;
      await storage.flush();

      expect(storage.getInt('a'), 2);
    });

    test('flush completes when nothing is pending', () async {
      await storage.flush();
    });

    test('keys is a snapshot, so a caller may remove keys while iterating it', () {
      storage
        ..setInt('a', 1)
        ..setString('b', 'x')
        ..setNull('c');

      final keys = storage.keys;
      keys.forEach(storage.remove);

      expect(keys, unorderedEquals(['a', 'b', 'c']));
      expect(storage.keys, isEmpty);
    });

    test('a flush scoped to keys waits for the writes issued before it and completes when they persist', () async {
      storage
        ..setInt('a', 1)
        ..setString('b', 'x');

      await storage.flush(keys: ['a']);
      await storage.flush(keys: ['never written']);
      await storage.flush(keys: const []);

      expect(storage.getInt('a'), 1);
      expect(storage.getString('b'), 'x');
    });

    group('key listeners', () {
      late int notified;
      late int otherNotified;
      void onK() => notified++;
      void onOther() => otherNotified++;

      setUp(() {
        notified = 0;
        otherNotified = 0;
        storage
          ..addKeyListener('k', onK)
          ..addKeyListener('other', onOther);
      });

      test('every typed setter, setNull and remove notify the key, and only that key', () {
        storage
          ..setBool('k', true)
          ..setInt('k', 1)
          ..setDouble('k', 1.5)
          ..setString('k', 's')
          ..setNull('k')
          ..remove('k');

        expect(notified, 6);
        expect(otherNotified, 0);
      });

      test('the listener runs synchronously, after the in-memory state changed', () {
        int? seen;
        storage.addKeyListener('k', () => seen = storage.getInt('k'));

        storage.setInt('k', 42);

        expect(seen, 42);
      });

      test('clear notifies every registered key', () async {
        storage.setInt('k', 1);
        notified = 0;

        await storage.clear();

        expect(notified, 1);
        expect(otherNotified, 1, reason: 'also keys that held nothing');
      });

      test('a removed listener is not called again', () {
        storage.removeKeyListener('k', onK);
        storage.setInt('k', 1);
        expect(notified, 0);
      });

      test('a listener removed by another one during a notification is not called by it', () {
        var removedNotified = 0;
        void removed() => removedNotified++;
        storage
          ..addKeyListener('k', () => storage.removeKeyListener('k', removed))
          ..addKeyListener('k', removed);

        storage.setInt('k', 1);

        expect(removedNotified, 0);
        expect(observer.events, isEmpty);
      });

      test('a listener added during a notification is first called on the next change', () {
        var addedNotified = 0;
        var added = false;
        storage.addKeyListener('k', () {
          if (added) return;
          added = true;
          storage.addKeyListener('k', () => addedNotified++);
        });

        storage.setInt('k', 1);
        expect(addedNotified, 0);

        storage.setInt('k', 2);
        expect(addedNotified, 1);
      });

      test('a throwing listener is reported and neither aborts the mutation nor starves later listeners', () {
        var laterNotified = 0;
        storage
          ..removeKeyListener('k', onK)
          ..addKeyListener('k', () => throw StateError('boom'))
          ..addKeyListener('k', () => laterNotified++);

        storage.setInt('k', 1);

        expect(storage.getInt('k'), 1);
        expect(laterNotified, 1);
        final event = observer.events.single;
        expect(
          event,
          isA<ListenerErrorEvent>()
              .having((e) => e.source, 'source', ListenerSource.storageKey)
              .having((e) => e.key, 'key', 'k')
              .having((e) => e.error, 'error', isA<StateError>()),
        );
        expect(event.stackTrace, isNotNull);
      });
    });

    group('reload', () {
      test('with nothing written outside keeps every value and notifies nobody', () async {
        storage
          ..setInt('i', 1)
          ..setString('s', 'x')
          ..setNull('n');
        var notified = 0;
        for (final key in ['i', 's', 'n', 'absent']) {
          storage.addKeyListener(key, () => notified++);
        }

        await storage.reload();

        expect(storage.getInt('i'), 1);
        expect(storage.getString('s'), 'x');
        expect(storage.hasNull('n'), isTrue);
        expect(storage.keys, unorderedEquals(['i', 's', 'n']));
        expect(notified, 0);
        await storage.flush();
      });

      test('keeps a value written while it runs', () async {
        storage.setInt('k', 1);

        final reloading = storage.reload();
        storage.setInt('k', 2);
        await reloading;
        await storage.flush();

        expect(storage.getInt('k'), 2);
      });

      test('a reload called while another runs completes too', () async {
        storage.setInt('k', 1);

        await Future.wait([storage.reload(), storage.reload()]);

        expect(storage.getInt('k'), 1);
      });
    });

    if (writeOutside != null) {
      group('reload after a write made outside the storage', () {
        test('nothing sees the write before the reload', () async {
          storage.setInt('k', 1);
          await storage.flush();

          await writeOutside(storage, 'k', 2);

          expect(storage.getInt('k'), 1);
        });

        test(
          'reads the new value and notifies that key once, the others not, with every key already updated',
          () async {
            storage
              ..setInt('k', 1)
              ..setInt('other', 5);
            await storage.flush();
            final seen = <int?>[];
            var otherNotified = 0;
            storage
              ..addKeyListener('k', () => seen.add(storage.getInt('added')))
              ..addKeyListener('other', () => otherNotified++);

            await writeOutside(storage, 'k', 2);
            await writeOutside(storage, 'added', 3);
            await storage.reload();

            expect(storage.getInt('k'), 2);
            expect(storage.getInt('added'), 3);
            expect(storage.keys, unorderedEquals(['k', 'other', 'added']));
            expect(seen, [3], reason: 'one notification, after every key was updated');
            expect(otherNotified, 0);
          },
        );

        test('a key removed outside reads as absent', () async {
          storage.setInt('k', 1);
          await storage.flush();
          var notified = 0;
          storage.addKeyListener('k', () => notified++);

          await writeOutside(storage, 'k', null);
          await storage.reload();

          expect(storage.getInt('k'), isNull);
          expect(storage.keys, isEmpty);
          expect(notified, 1);
        });

        test('a setting over the key reads the new value and tells its listeners', () async {
          final setting = IntSetting(storage: storage, key: 'k', defaultValue: 0);
          addTearDown(setting.dispose);
          final values = <int>[];
          setting.addListener(() => values.add(setting.value));
          expect(setting.value, 0);

          await writeOutside(storage, 'k', 42);
          await storage.reload();

          expect(setting.value, 42);
          expect(setting.hasStoredValue, isTrue);
          expect(values, [42]);
        });

        test('a key written while the reload runs keeps that value, and it is what persists', () async {
          storage.setInt('k', 1);
          await storage.flush();
          await writeOutside(storage, 'k', 2);

          final reloading = storage.reload();
          storage.setInt('k', 3);
          await reloading;
          await storage.flush();

          expect(storage.getInt('k'), 3);
          await storage.reload();
          expect(storage.getInt('k'), 3, reason: 'the backend holds the later write');
        });

        test('a storage cleared while the reload runs stays cleared', () async {
          storage.setInt('k', 1);
          await storage.flush();
          await writeOutside(storage, 'k', 2);

          final reloading = storage.reload();
          final cleared = storage.clear();
          await reloading;
          await cleared;

          expect(storage.getInt('k'), isNull);
        });
      });
    }

    group('close', () {
      test(
        'completes after earlier writes, and then every read, write and listener registration throws a StateError',
        () async {
          void listener() {}
          storage
            ..setInt('k', 1)
            ..addKeyListener('k', listener);

          await storage.close();

          expect(() => storage.getBool('k'), throwsStateError);
          expect(() => storage.getInt('k'), throwsStateError);
          expect(() => storage.getDouble('k'), throwsStateError);
          expect(() => storage.getString('k'), throwsStateError);
          expect(() => storage.hasNull('k'), throwsStateError);
          expect(() => storage.setBool('k', true), throwsStateError);
          expect(() => storage.setInt('k', 2), throwsStateError);
          expect(() => storage.setDouble('k', 1.5), throwsStateError);
          expect(() => storage.setString('k', 's'), throwsStateError);
          expect(() => storage.setNull('k'), throwsStateError);
          expect(() => storage.remove('k'), throwsStateError);
          await expectLater(storage.clear, throwsStateError);
          await expectLater(storage.reload, throwsStateError);
          expect(() => storage.addKeyListener('k', () {}), throwsStateError);
          expect(observer.events, isEmpty);
        },
      );

      test('leaves removing a listener and flush allowed', () async {
        void listener() {}
        storage.addKeyListener('k', listener);
        await storage.close();

        storage.removeKeyListener('k', listener);
        await storage.flush();
      });

      test('returns the same future when called again', () {
        final closing = storage.close();

        expect(storage.close(), same(closing));
        return closing;
      });

      test('is reported by isClosed from the call on', () {
        expect(storage.isClosed, isFalse);

        final closing = storage.close();

        expect(storage.isClosed, isTrue);
        return closing;
      });
    });
  });
}

/// Writes to the backend of [storage] without going through it, as
/// another isolate or native code would: stores the int [value] under the
/// setting key [key] the way the storage itself stores an int there, or
/// removes the key when [value] is `null`. Completes once the backend
/// holds the change.
typedef OutsideWrite = Future<void> Function(SettingsStorage storage, String key, int? value);
