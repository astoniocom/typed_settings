import 'dart:convert';

import 'package:meta/meta.dart' show immutable;
import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

import 'package:typed_settings_conformance/typed_settings_conformance.dart';

/// [InMemoryStorage] that counts calls, to assert caching behavior.
final class TrackingStorage extends InMemoryStorage {
  TrackingStorage({super.observer});

  int getIntCalls = 0;
  int setIntCalls = 0;
  int getStringCalls = 0;
  int removeCalls = 0;
  int addKeyListenerCalls = 0;

  @override
  void addKeyListener(String key, void Function() listener) {
    addKeyListenerCalls++;
    super.addKeyListener(key, listener);
  }

  @override
  int? getInt(String key) {
    getIntCalls++;
    return super.getInt(key);
  }

  @override
  void setInt(String key, int value) {
    setIntCalls++;
    super.setInt(key, value);
  }

  @override
  String? getString(String key) {
    getStringCalls++;
    return super.getString(key);
  }

  @override
  void remove(String key) {
    removeCalls++;
    super.remove(key);
  }
}

/// Codec that encodes by doubling, so that an odd raw value is data it
/// never wrote: [decode] rejects it with a [FormatException], to exercise
/// the base-class error handling on read.
class ExplodingCodec implements SettingCodec<int, int> {
  const ExplodingCodec();

  @override
  int decode(int raw) => raw.isEven ? raw ~/ 2 : throw const FormatException('boom');

  @override
  int encode(int value) => value * 2;
}

/// Like [ExplodingCodec], but [decode] throws an [Error] for an odd raw
/// value, i.e. has a bug.
class BuggyCodec implements SettingCodec<int, int> {
  const BuggyCodec();

  @override
  int decode(int raw) => raw.isEven ? raw ~/ 2 : throw StateError('bug');

  @override
  int encode(int value) => value * 2;
}

/// A custom value type stored through a user-defined codec, to show that a
/// new setting type needs no subclass of [StoredSetting].
@immutable
class Point {
  const Point(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Throws [StateError] from every int read, as a storage with a bug does.
final class _ThrowingIntStorage extends InMemoryStorage {
  @override
  int? getInt(String key) => throw StateError('closed');
}

/// Rejects every int write while [rejecting] is set, before changing
/// anything.
final class _RejectingStorage extends InMemoryStorage {
  bool rejecting = false;

  @override
  void setInt(String key, int value) {
    if (rejecting) throw StateError('read-only');
    super.setInt(key, value);
  }
}

/// A [Point] made by a `snapshot`, to tell copies from the originals.
class _CopiedPoint extends Point {
  const _CopiedPoint(super.x, super.y);
}

class PointCodec implements SettingCodec<Point, String> {
  const PointCodec();

  @override
  Point decode(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) throw FormatException('Expected `x,y`', raw);
    return Point(int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  String encode(Point value) => '${value.x},${value.y}';
}

void main() {
  late RecordingObserver observer;
  late TrackingStorage storage;

  setUp(() {
    observer = RecordingObserver();
    storage = TrackingStorage(observer: observer);
  });

  IntSetting intSetting({
    int defaultValue = 7,
    SettingValidator<int>? validator,
  }) {
    return IntSetting(
      storage: storage,
      key: 'k',
      defaultValue: defaultValue,
      validator: validator,
    );
  }

  group('read', () {
    test('returns defaultValue when storage is empty', () {
      expect(intSetting().value, 7);
    });

    test('returns the stored value', () {
      storage.setInt('k', 42);
      expect(intSetting().value, 42);
    });

    test('caches the value: storage is read once', () {
      storage.setInt('k', 42);
      final setting = intSetting();
      expect(setting.value, 42);
      expect(setting.value, 42);
      expect(storage.getIntCalls, 1);
    });

    test('defaultValue is also cached: empty storage is read once', () {
      final setting = intSetting();
      expect(setting.value, 7);
      expect(setting.value, 7);
      expect(storage.getIntCalls, 1);
    });

    test('decode failure is reported, falls back to defaultValue and caches it', () {
      storage.setInt('k', 1);
      final setting = StoredSetting<int, int>(
        slot: KeyedSettingSlot.ofInt(storage, key: 'k'),
        defaultValue: 7,
        codec: const ExplodingCodec(),
      );
      expect(setting.value, 7);
      expect(setting.value, 7);
      expect(storage.getIntCalls, 1, reason: 'failing read must not be retried');
      expect(observer.messages, hasLength(1));
      expect(observer.messages.single, contains('`k`'));
    });

    test('an Error thrown by the codec on stored data is reported with its stack trace and falls back too', () {
      storage.setInt('k', 1);
      final setting = StoredSetting<int, int>(
        slot: KeyedSettingSlot.ofInt(storage, key: 'k'),
        defaultValue: 7,
        codec: const BuggyCodec(),
      );
      expect(setting.value, 7);
      expect(setting.value, 7);
      expect(storage.getIntCalls, 1, reason: 'failing read must not be retried');
      expect(
        observer.events.single,
        isA<DecodeFallbackEvent>()
            .having((e) => e.error, 'error', isA<StateError>())
            .having((e) => e.stackTrace, 'stackTrace', isNotNull),
      );
    });

    test('invariant failure on read is reported and falls back to defaultValue', () {
      storage.setInt('k', -1);
      final setting = intSetting(
        validator: SettingValidator((v) => v < 0 ? ForbiddenValueValidationError(v) : null),
      );
      expect(setting.value, 7);
      expect(observer.messages.single, contains('Validation failed on read'));
    });
  });

  group('write', () {
    test('persists the value and notifies listeners', () {
      final setting = intSetting();
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = 42;

      expect(storage.getInt('k'), 42);
      expect(setting.value, 42);
      expect(notifications, 1);
    });

    test('writing a value equal to the cached one is a no-op', () {
      storage.setInt('k', 42);
      final setting = intSetting();
      expect(setting.value, 42); // warm the cache
      storage.setIntCalls = 0;
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = 42;

      expect(storage.setIntCalls, 0);
      expect(notifications, 0);
    });

    test('writing the stored value to a cold setting is a no-op too', () {
      storage.setInt('k', 42);
      storage.setIntCalls = 0;
      final setting = intSetting(); // cache is cold
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = 42;

      expect(storage.setIntCalls, 0);
      expect(notifications, 0);
      expect(storage.getIntCalls, 1, reason: 'the comparison reads the stored value once');
    });

    test('writing the default to a cold setting over an empty storage stores it, once', () {
      final setting = intSetting(); // defaultValue 7
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = 7;
      setting.value = 7;

      expect(storage.contents, {'k': 7});
      expect(storage.setIntCalls, 1);
      expect(notifications, 1, reason: 'the value is the same, but it is a stored one now');
    });

    test('writing the default over an undecodable stored value keeps that value', () {
      storage.setInt('k', 1);
      final setting = StoredSetting<int, int>(
        slot: KeyedSettingSlot.ofInt(storage, key: 'k'),
        defaultValue: 7,
        codec: const ExplodingCodec(),
      );
      var notifications = 0;
      setting.addListener(() => notifications++);
      final writes = storage.setIntCalls;

      setting.value = 7; // equal to the fallback the getter reports

      expect(storage.getInt('k'), 1, reason: 'a later release or a fixed codec may still read it');
      expect(storage.setIntCalls, writes);
      expect(notifications, 0);
      expect(setting.hasStoredValue, isFalse);
      expect(observer.events.single, isA<ReadFallbackEvent>());
    });

    test('committing the default over an undecodable stored value keeps that value', () async {
      storage.setInt('k', 1);
      final setting = StoredSetting<int, int>(
        slot: KeyedSettingSlot.ofInt(storage, key: 'k'),
        defaultValue: 7,
        codec: const ExplodingCodec(),
      );
      final writes = storage.setIntCalls;

      await setting.commit(7);

      expect(storage.getInt('k'), 1);
      expect(storage.setIntCalls, writes);
    });

    test('writing the default over a stored value the invariant rejects keeps that value', () {
      storage.setInt('k', -1);
      final setting = intSetting(
        validator: SettingValidator((v) => v < 0 ? ForbiddenValueValidationError(v) : null),
      );

      setting.value = 7; // the default

      expect(storage.getInt('k'), -1);
      expect(setting.value, 7);
    });

    test('another value replaces an unusable stored value, and reset removes it', () {
      storage.setInt('k', -1);
      final setting = intSetting(
        validator: SettingValidator((v) => v < 0 ? ForbiddenValueValidationError(v) : null),
      );

      setting.value = 8;
      expect(storage.getInt('k'), 8);

      storage.setInt('k', -1);
      setting.reset();
      expect(storage.contents, isEmpty);

      setting.value = 7;
      expect(storage.getInt('k'), 7, reason: 'with nothing stored, the default is a choice that is stored');
    });

    // Note: in debug mode the constructor itself runs the invariant once
    // against defaultValue (an assert), so counting starts after construction.

    test('a shared check runs once per write', () {
      var calls = 0;
      ValidationError? check(int v) {
        calls++;
        return null;
      }

      final setting = intSetting(validator: SettingValidator(check));
      calls = 0;

      setting.value = 1;
      expect(calls, 1);
    });

    test('split checks both run on write, write guard first', () {
      final order = <String>[];
      final setting = intSetting(
        validator: SettingValidator.split(
          writeGuard: (v) {
            order.add('write');
            return null;
          },
          invariant: (v) {
            order.add('read');
            return null;
          },
        ),
      );
      order.clear();

      setting.value = 1;
      expect(order, ['write', 'read']);
    });

    test('the write guard short-circuits the invariant', () {
      var readCalls = 0;
      final setting = intSetting(
        validator: SettingValidator.split(
          writeGuard: (v) => const ForbiddenValueValidationError(1),
          invariant: (v) {
            readCalls++;
            return null;
          },
        ),
      );
      readCalls = 0;

      expect(setting.validate(1), const ForbiddenValueValidationError(1));
      expect(readCalls, 0);
    });

    test('SettingValidator.all applies validators in order and stops at the first error', () {
      const negative = ForbiddenValueValidationError(-1);
      const tooBig = ForbiddenValueValidationError(101);
      var secondReadCalls = 0;
      final setting = intSetting(
        validator: SettingValidator.all([
          SettingValidator((v) => v < 0 ? negative : null),
          SettingValidator.split(
            invariant: (v) {
              secondReadCalls++;
              return v > 100 ? tooBig : null;
            },
          ),
        ]),
      );
      secondReadCalls = 0;

      expect(setting.validate(5), isNull);
      expect(setting.validate(101), tooBig);
      expect(setting.validate(-1), negative);
      expect(secondReadCalls, 2, reason: 'not consulted once the first validator failed');
    });

    test('validation error throws SettingValidationException and persists nothing', () {
      const error = ForbiddenValueValidationError(-1);
      final setting = intSetting(validator: SettingValidator((v) => v < 0 ? error : null));
      var notifications = 0;
      setting.addListener(() => notifications++);

      expect(
        () => setting.value = -1,
        throwsA(
          isA<SettingValidationException>()
              .having((e) => e.diagnosticKey, 'debugKey', 'k')
              .having((e) => e.error, 'error', error),
        ),
      );
      expect(storage.getInt('k'), isNull);
      expect(setting.value, 7);
      expect(notifications, 0);
    });

    test(
      'a defaultValue the validator rejects is an ArgumentError, before anything is registered with the storage',
      () {
        expect(
          () => intSetting(validator: SettingValidator((v) => const ForbiddenValueValidationError(7))),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'defaultValue')),
        );
        expect(storage.addKeyListenerCalls, 0);
      },
    );

    test('an enum defaultValue outside values is an ArgumentError, before anything is registered with the storage', () {
      expect(
        () => EnumSetting<TestEnum>(
          storage: storage,
          key: 'e',
          defaultValue: TestEnum.b,
          values: const [TestEnum.a],
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'defaultValue')),
      );
      expect(
        () => EnumNullableSetting<TestEnum>(
          storage: storage,
          key: 'e',
          defaultValue: TestEnum.b,
          values: const [TestEnum.a],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        EnumNullableSetting<TestEnum>(
          storage: storage,
          key: 'e',
          values: const [TestEnum.a],
        ).value,
        isNull,
      );
      expect(storage.addKeyListenerCalls, 1, reason: 'only the valid setting registered');
    });
  });

  group('observer', () {
    test("a setting reports through its storage's observer by default", () {
      final storageObserver = RecordingObserver();
      final observedStorage = InMemoryStorage(observer: storageObserver)..setInt('k', -1);
      final setting = IntSetting(
        storage: observedStorage,
        key: 'k',
        defaultValue: 7,
        validator: SettingValidator((v) => v < 0 ? ForbiddenValueValidationError(v) : null),
      );

      expect(setting.value, 7);
      final event = storageObserver.events.single;
      expect(
        event,
        isA<ValidationFallbackEvent>()
            .having((e) => e.key, 'key', setting.diagnosticKey)
            .having((e) => e.error, 'error', const ForbiddenValueValidationError(-1))
            .having((e) => e.stackTrace, 'stackTrace', isNull),
      );
    });
  });

  group('Setting<T> contract', () {
    test('concrete settings are usable through Setting<T>', () {
      final Setting<int> setting = intSetting();
      final observed = <int>[];
      setting.addListener(() => observed.add(setting.value));

      setting.value = 42;

      expect(setting.diagnosticKey, 'k');
      expect(setting.defaultValue, 7);
      expect(observed, [42]);
      expect(setting.isDefault, isFalse);
    });

    test('validate mirrors the setter: null when accepted, the error otherwise', () {
      const tooBig = ForbiddenValueValidationError(101);
      const negative = ForbiddenValueValidationError(-1);
      final Setting<int> setting = intSetting(
        validator: SettingValidator.split(
          writeGuard: (v) => v < 0 ? negative : null,
          invariant: (v) => v > 100 ? tooBig : null,
        ),
      );

      expect(setting.validate(5), isNull);
      expect(setting.validate(-1), negative);
      expect(setting.validate(101), tooBig);
      expect(
        () => setting.value = 101,
        throwsA(isA<SettingValidationException>().having((e) => e.error, 'error', tooBig)),
      );
    });

    test('validate does not write, cache or notify', () {
      final setting = intSetting();
      var notifications = 0;
      setting.addListener(() => notifications++);

      expect(setting.validate(42), isNull);

      expect(storage.getInt('k'), isNull);
      expect(setting.value, 7);
      expect(notifications, 0);
    });
  });

  group('invalidate', () {
    test('drops the cache so the next read hits storage, without notifying', () {
      storage.setInt('k', 1);
      final setting = intSetting();
      var notifications = 0;
      setting.addListener(() => notifications++);
      expect(setting.value, 1);
      expect(storage.getIntCalls, 1);

      setting.invalidate();
      expect(notifications, 0);
      expect(setting.value, 1);
      expect(storage.getIntCalls, 2, reason: 'read again after invalidate');
    });
  });

  group('ReadOnlySetting', () {
    test('exposes the read side of a setting, including change notification', () async {
      final setting = intSetting();
      final ReadOnlySetting<int> view = setting;
      var notified = 0;
      view.addListener(() => notified++);
      final emitted = <int>[];
      final subscription = view.asStream().listen(emitted.add);

      setting.value = 3;
      await Future<void>.delayed(Duration.zero);

      expect(view.diagnosticKey, 'k');
      expect(view.defaultValue, 7);
      expect(view.value, 3);
      expect(view.isDefault, isFalse);
      expect(notified, 1);
      expect(emitted, [7, 3]);
      await subscription.cancel();
    });
  });

  group('listeners', () {
    test('are called in registration order, once per registration', () {
      final setting = intSetting();
      final calls = <String>[];
      void a() => calls.add('a');
      void b() => calls.add('b');
      setting
        ..addListener(a)
        ..addListener(b)
        ..addListener(a);

      setting.value = 1;

      expect(calls, ['a', 'b', 'a']);
    });

    test('removeListener removes one registration and is a no-op for an unknown listener', () {
      final setting = intSetting();
      var calls = 0;
      void listener() => calls++;
      setting
        ..addListener(listener)
        ..addListener(listener)
        ..removeListener(listener)
        ..removeListener(() {});

      setting.value = 1;

      expect(calls, 1);
    });

    test('a throwing listener is reported and the remaining listeners still run', () {
      final setting = intSetting();
      var secondCalled = false;
      setting
        ..addListener(() => throw StateError('listener bug'))
        ..addListener(() => secondCalled = true);

      setting.value = 1;

      expect(secondCalled, isTrue);
      expect(storage.getInt('k'), 1, reason: 'the change stays applied');
      expect(
        observer.events.single,
        isA<ListenerErrorEvent>()
            .having((e) => e.source, 'source', ListenerSource.setting)
            .having((e) => e.key, 'key', 'k')
            .having((e) => e.error, 'error', isA<StateError>()),
      );
    });

    test('a listener removed by another during a notification is not called by it', () {
      final setting = intSetting();
      var removedCalls = 0;
      void removed() => removedCalls++;
      setting
        ..addListener(() => setting.removeListener(removed))
        ..addListener(removed);

      setting.value = 1;

      expect(removedCalls, 0);
      expect(observer.events, isEmpty);
    });

    test('a listener that disposes the setting ends the notification without an error', () {
      final setting = intSetting();
      var laterCalls = 0;
      setting
        ..addListener(setting.dispose)
        ..addListener(() => laterCalls++);

      setting.value = 1;

      expect(laterCalls, 0);
      expect(observer.events, isEmpty);
    });

    test('a setting disposed by a listener of another one over the key is not notified of the change', () {
      final observer = RecordingObserver();
      final observed = InMemoryStorage(observer: observer);
      final first = IntSetting(storage: observed, key: 'k', defaultValue: 0)..value;
      final second = IntSetting(storage: observed, key: 'k', defaultValue: 0)..value;
      var secondCalls = 0;
      second.addListener(() => secondCalls++);
      first.addListener(second.dispose);

      observed.setInt('k', 1);

      expect(secondCalls, 0);
      expect(observer.events, isEmpty, reason: 'the storage does not call the key listener second removed');
    });

    test('a setting disposed during its own write by a listener of another one completes the write', () {
      final first = IntSetting(storage: storage, key: 'k', defaultValue: 0)..value;
      final second = IntSetting(storage: storage, key: 'k', defaultValue: 0)..value;
      var firstCalls = 0;
      first.addListener(() => firstCalls++);
      second.addListener(first.dispose);

      first.value = 5;

      expect(storage.getInt('k'), 5);
      expect(second.value, 5);
      expect(firstCalls, 0, reason: 'a disposed setting tells no one');
      expect(() => first.value, throwsStateError);
    });

    test('a listener added during a notification is first called on the next change', () {
      final setting = intSetting();
      var addedCalls = 0;
      var added = false;
      setting.addListener(() {
        if (added) return;
        added = true;
        setting.addListener(() => addedCalls++);
      });

      setting.value = 1;
      expect(addedCalls, 0);

      setting.value = 2;
      expect(addedCalls, 1);
    });

    test('dispose drops the listeners and the storage registration', () {
      final setting = intSetting();
      var calls = 0;
      setting.addListener(() => calls++);

      setting.dispose();
      storage.setInt('k', 5);

      expect(calls, 0);
    });

    test('every operation on a disposed setting throws a StateError, and nothing reaches the storage', () async {
      final setting = intSetting()..dispose();
      final throwsDisposed = throwsA(
        isA<StateError>().having((e) => e.message, 'message', contains('disposed setting `k`')),
      );

      expect(() => setting.value, throwsDisposed);
      expect(() => setting.value = 1, throwsDisposed);
      await expectLater(setting.commit(1), throwsDisposed);
      expect(setting.reset, throwsDisposed);
      expect(() => setting.validate(1), throwsDisposed);
      expect(() => setting.hasStoredValue, throwsDisposed);
      expect(setting.invalidate, throwsDisposed);
      expect(() => setting.addListener(() {}), throwsDisposed);
      expect(setting.asStream, throwsDisposed);

      expect(storage.contents, isEmpty);
      expect(storage.setIntCalls, 0);
      expect(storage.removeCalls, 0);
    });

    test('disposing twice is a harmless bug, reported in debug mode', () {
      final setting = intSetting()..dispose();

      expect(setting.dispose, throwsA(isA<AssertionError>()));
    });
  });

  group('coherence with the storage', () {
    test('a write through another instance over the same key is seen and notified', () {
      final a = intSetting();
      final b = intSetting();
      expect(b.value, 7); // warm b's cache
      var bNotified = 0;
      b.addListener(() => bNotified++);

      a.value = 3;

      expect(bNotified, 1);
      expect(b.value, 3);
    });

    test('a faulty key listener leaves the writer, other instances and the storage in agreement', () {
      final observer = RecordingObserver();
      final storage = InMemoryStorage(observer: observer);
      final a = IntSetting(storage: storage, key: 'k', defaultValue: 7);
      expect(a.value, 7);
      storage.addKeyListener('k', () => throw StateError('boom'));
      final b = IntSetting(storage: storage, key: 'k', defaultValue: 7);
      expect(b.value, 7);
      var bNotified = 0;
      b.addListener(() => bNotified++);

      a.value = 9;

      expect(storage.getInt('k'), 9);
      expect(a.value, 9);
      expect(b.value, 9);
      expect(bNotified, 1);
      expect(
        observer.events.single,
        isA<ListenerErrorEvent>().having((e) => e.source, 'source', ListenerSource.storageKey),
      );
    });

    test('whoever the storage notifies of a write reads the new value from the writer', () {
      final a = intSetting();
      final b = intSetting();
      expect(b.value, 7);
      final seen = <int>[];
      b.addListener(() => seen.add(a.value));
      storage.addKeyListener('k', () => seen.add(a.value));

      a.value = 3;

      expect(seen, [3, 3]);
    });

    test(
      'a listener that writes the key again in response leaves the writer, the other instance and the storage in agreement',
      () {
        final a = intSetting();
        final b = intSetting();
        expect(b.value, 7);
        final seenFromA = <int>[];
        b.addListener(() {
          seenFromA.add(a.value);
          if (b.value > 10) b.value = 10;
        });
        final notifiedA = <int>[];
        a.addListener(() => notifiedA.add(a.value));

        a.value = 50;

        expect(seenFromA, [50, 10], reason: 'at every notification the writer holds what the storage holds');
        expect([a.value, b.value, storage.getInt('k')], [10, 10, 10]);
        expect(notifiedA, [10]);
      },
    );

    test('a key listener that overrides a write is seen by the writer, which tells its listeners once', () {
      final setting = intSetting();
      storage.addKeyListener('k', () {
        if (storage.getInt('k') == 50) storage.setInt('k', 10);
      });
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = 50;

      expect(setting.value, 10);
      expect(notifications, 1);
    });

    test('commit of the current value tells its listeners when a listener changes the key in response', () async {
      final setting = intSetting()..value = 5;
      storage.addKeyListener('k', () {
        if (storage.getInt('k') == 5) storage.setInt('k', 6);
      });
      var notifications = 0;
      setting.addListener(() => notifications++);

      await setting.commit(5);

      expect(setting.value, 6);
      expect(notifications, 1);
    });

    test('reset of a value read from a legacy key notifies once and reads the default', () {
      storage.setInt('old', 5);
      final setting = IntSetting(
        storage: storage,
        key: 'k',
        legacyKeys: const ['old'],
        defaultValue: 0,
      );
      expect(setting.value, 5);
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.reset();

      expect(notifications, 1);
      expect(setting.value, 0);
      expect(storage.getInt('old'), isNull);
    });

    test('a write the storage rejects propagates and leaves the setting reading what the storage holds', () {
      final storage = _RejectingStorage()..setInt('k', 1);
      final setting = IntSetting(storage: storage, key: 'k', defaultValue: 0);
      expect(setting.value, 1);
      var notifications = 0;
      setting.addListener(() => notifications++);
      storage.rejecting = true;

      expect(() => setting.value = 2, throwsStateError);

      expect(setting.value, 1);
      expect(notifications, 0);
    });

    test('reset through another instance is seen', () {
      final a = intSetting()..value = 3;
      final b = intSetting();
      expect(b.value, 3);

      a.reset();

      expect(b.value, 7);
    });

    test('a storage change of the key drops a cached fallback and reads again', () {
      storage.setInt('k', 1);
      final setting = StoredSetting<int, int>(
        slot: KeyedSettingSlot.ofInt(storage, key: 'k'),
        defaultValue: 7,
        codec: const ExplodingCodec(),
      );
      expect(setting.value, 7);
      expect(observer.events.single, isA<DecodeFallbackEvent>());

      storage.setInt('k', const ExplodingCodec().encode(2));

      expect(setting.value, 2);
    });

    test('a direct write to the storage is seen', () {
      storage.setInt('k', 1);
      final setting = intSetting();
      expect(setting.value, 1);
      var notifications = 0;
      setting.addListener(() => notifications++);

      storage.setInt('k', 2);

      expect(notifications, 1);
      expect(setting.value, 2);
    });

    test('storage.clear() is seen', () async {
      final setting = intSetting()..value = 3;
      var notifications = 0;
      setting.addListener(() => notifications++);

      await storage.clear();

      expect(notifications, 1);
      expect(setting.value, 7);
    });

    test('storage.clear() of an already default setting is not notified', () async {
      final setting = intSetting();
      expect(setting.value, 7);
      var notifications = 0;
      setting.addListener(() => notifications++);

      await storage.clear();

      expect(notifications, 0);
      expect(setting.value, 7);
    });

    test('a write of an equal value through another instance is not notified', () {
      final a = intSetting()..value = 3;
      final b = intSetting();
      expect(b.value, 3);
      var notifications = 0;
      b.addListener(() => notifications++);

      a.value = 3;

      expect(notifications, 0);
    });

    test('a storage change that leaves the exposed value the same is not notified', () {
      storage.setInt('k', 1);
      final setting = StoredSetting<int, int>(
        slot: KeyedSettingSlot.ofInt(storage, key: 'k'),
        defaultValue: 7,
        codec: const ExplodingCodec(),
      );
      expect(setting.value, 7);
      var notifications = 0;
      setting.addListener(() => notifications++);
      observer.events.clear();

      storage.setInt('k', 3);

      expect(notifications, 0);
      expect(setting.value, 7);
      expect(observer.events.single, isA<DecodeFallbackEvent>(), reason: 'the new stored value is still unusable');
    });

    test("the setting's own write notifies its listeners exactly once", () {
      final setting = intSetting();
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = 3;
      final readsAfterWrite = storage.getIntCalls;

      expect(notifications, 1);
      expect(setting.value, 3);
      expect(storage.getIntCalls, readsAfterWrite, reason: 'the own write must not invalidate the fresh cache');
    });

    test('legacy key adoption does not notify the adopting instance', () {
      storage.setInt('old', 5);
      final setting = IntSetting(
        storage: storage,
        key: 'k',
        legacyKeys: const ['old'],
        defaultValue: 0,
      );
      var notifications = 0;
      setting.addListener(() => notifications++);

      expect(setting.value, 5);
      expect(notifications, 0);
    });

    test('a disposed setting is no longer called by the storage', () {
      final setting = intSetting();
      expect(setting.value, 7);
      setting.dispose();

      storage.setInt('k', 1); // would throw on a disposed ChangeNotifier if still registered
    });
  });

  group('reset', () {
    test('removes the stored value, returns defaultValue and notifies', () {
      final setting = intSetting();
      setting.value = 42;
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.reset();

      expect(storage.getInt('k'), isNull);
      expect(storage.removeCalls, 1);
      expect(setting.value, 7);
      expect(notifications, 1);
    });

    test('of an already absent key is a no-op: nothing is written or notified', () {
      final setting = intSetting();
      expect(setting.value, 7);
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.reset();

      expect(notifications, 0);
      expect(storage.removeCalls, 0);
    });

    test('of a stored value equal to the default still notifies, because the key is gone', () {
      storage.setInt('k', 7);
      final setting = intSetting();
      expect(setting.value, 7);
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.reset();

      expect(notifications, 1);
      expect(storage.getInt('k'), isNull);
      expect(setting.isDefault, isTrue);
    });
  });

  group('isDefault', () {
    test('true for defaultValue, false after write, true after reset', () {
      final setting = intSetting();
      expect(setting.isDefault, isTrue);
      setting.value = 42;
      expect(setting.isDefault, isFalse);
      setting.reset();
      expect(setting.isDefault, isTrue);
    });
  });

  group('hasStoredValue', () {
    test('is false while nothing is stored, and true once the default is assigned: the choice is stored', () {
      final setting = intSetting();
      expect(setting.isDefault, isTrue);
      expect(setting.hasStoredValue, isFalse);

      setting.value = 7;

      expect(storage.contents, {'k': 7});
      expect(setting.isDefault, isTrue);
      expect(setting.hasStoredValue, isTrue);
    });

    test('an assigned default stays when a later version changes the default', () {
      intSetting()
        ..value = 7
        ..dispose();

      final later = IntSetting(storage: storage, key: 'k', defaultValue: 9);

      expect(later.value, 7);
    });

    test('the setter and commit store the default alike', () async {
      final assigned = intSetting()..value = 7;
      final committed = IntSetting(storage: storage, key: 'other', defaultValue: 7);
      await committed.commit(7);

      expect(assigned.hasStoredValue, isTrue);
      expect(committed.hasStoredValue, isTrue);
    });

    test('is true when the stored value equals the default', () {
      storage.setInt('k', 7);
      final setting = intSetting();

      expect(setting.value, 7);
      expect(setting.isDefault, isTrue);
      expect(setting.hasStoredValue, isTrue);
    });

    test('stays true when the default replaces a different stored value', () {
      final setting = intSetting()..value = 1;

      setting.value = 7;

      expect(storage.getInt('k'), 7);
      expect(setting.isDefault, isTrue);
      expect(setting.hasStoredValue, isTrue);
    });

    test('becomes true when the default is committed over an empty key', () async {
      final setting = intSetting();

      await setting.commit(7);

      expect(storage.getInt('k'), 7);
      expect(setting.isDefault, isTrue);
      expect(setting.hasStoredValue, isTrue);
    });

    test('is true for a value still stored under a legacy key', () {
      storage.setInt('old', 7);
      final setting = IntSetting(
        storage: storage,
        key: 'k',
        legacyKeys: const ['old'],
        defaultValue: 7,
      );

      expect(setting.value, 7);
      expect(setting.isDefault, isTrue);
      expect(setting.hasStoredValue, isTrue);
      expect(storage.getInt('k'), isNull);
    });

    test('a reset of a stored default under a legacy key notifies, since it is no longer stored', () {
      storage.setInt('old', 7);
      final setting = IntSetting(storage: storage, key: 'k', legacyKeys: const ['old'], defaultValue: 7);
      expect(setting.hasStoredValue, isTrue);
      var notified = 0;
      setting.addListener(() => notified++);

      setting.reset();

      expect(setting.value, 7);
      expect(setting.hasStoredValue, isFalse);
      expect(notified, 1);
    });

    test('is false when the stored value is unusable and the default stands in', () {
      storage.setInt('k', 1);
      final setting = StoredSetting<int, int>(
        slot: KeyedSettingSlot.ofInt(storage, key: 'k'),
        defaultValue: 7,
        codec: const ExplodingCodec(),
      );

      expect(setting.value, 7);
      expect(setting.isDefault, isTrue);
      expect(setting.hasStoredValue, isFalse);
    });

    test('is false when the value under a legacy key is unusable and the default stands in', () {
      storage.setInt('old', 1);
      final setting = StoredSetting<int, int>(
        slot: KeyedSettingSlot.ofInt(storage, key: 'k', legacyKeys: const ['old']),
        defaultValue: 7,
        codec: const ExplodingCodec(),
      );

      expect(setting.value, 7);
      expect(setting.hasStoredValue, isFalse);
    });

    test('is true for an explicit null, and false for an explicit null a non-nullable setting ignores', () {
      final nullable = IntNullableSetting(storage: storage, key: 'n');
      expect(nullable.hasStoredValue, isFalse);

      nullable.value = 1;
      nullable.value = null;

      expect(storage.hasNull('n'), isTrue);
      expect(nullable.isDefault, isTrue);
      expect(nullable.hasStoredValue, isTrue);

      storage.setNull('k');
      expect(intSetting().hasStoredValue, isFalse);
    });

    test('reset of a stored default clears it', () {
      storage.setInt('k', 7);
      final setting = intSetting();

      setting.reset();

      expect(setting.hasStoredValue, isFalse);
      expect(setting.isDefault, isTrue);
    });

    test('after reset, assigning the default stores it, as on a setting that never stored one', () {
      storage.setInt('k', 1);
      final setting = intSetting();
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.reset();
      expect(setting.hasStoredValue, isFalse);
      setting.value = 7;

      expect(storage.contents, {'k': 7});
      expect(setting.hasStoredValue, isTrue);
      expect(notifications, 2, reason: 'the reset, then the default becoming a stored value');
    });
  });

  group('asStream', () {
    test('emits the current value, then changes, and skips a no-op', () async {
      final setting = intSetting();
      final emitted = <int>[];
      final subscription = setting.asStream().listen(emitted.add);

      setting.value = 1;
      setting.value = 2;
      setting.value = 2; // no change
      setting.reset();
      setting.reset(); // already absent
      await Future<void>.delayed(Duration.zero);

      expect(emitted, [7, 1, 2, 7]);
      await subscription.cancel();
    });

    test('a listener that arrives later receives the value at that moment', () async {
      final setting = intSetting();
      final early = <int>[];
      final late = <int>[];
      final first = setting.asStream().listen(early.add);
      setting.value = 1;
      setting.value = 3;
      final second = setting.asStream().listen(late.add);
      await Future<void>.delayed(Duration.zero);

      expect(early, [7, 1, 3]);
      expect(late, [3], reason: 'a new subscription does not replay earlier changes');
      expect(setting.asStream().isBroadcast, isTrue);
      await first.cancel();
      await second.cancel();
    });

    test('the same stream accepts a listener after the last one cancels', () async {
      final setting = intSetting();
      final stream = setting.asStream();
      await stream.listen((_) {}).cancel();

      final emitted = <int>[];
      var done = false;
      final second = stream.listen(emitted.add, onDone: () => done = true);
      setting.value = 5;
      await Future<void>.delayed(Duration.zero);

      expect(done, isFalse, reason: 'cancel does not close the stream');
      expect(emitted, [7, 5]);
      expect(identical(setting.asStream(), stream), isTrue);
      await second.cancel();
    });

    test('emits a change made through the storage', () async {
      final setting = intSetting();
      final emitted = <int>[];
      final subscription = setting.asStream().listen(emitted.add);

      storage.setInt('k', 4);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, [7, 4]);
      await subscription.cancel();
    });

    test('a failure to read the current value is an error on the subscription', () async {
      final setting = IntSetting(storage: _ThrowingIntStorage(), key: 'k', defaultValue: 7);
      final emitted = <int>[];
      Object? error;
      final subscription = setting.asStream().listen(emitted.add, onError: (Object e) => error = e);
      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty);
      expect(error, isA<StateError>());
      await subscription.cancel();
    });

    test('closes on dispose', () async {
      final setting = intSetting();
      final stream = setting.asStream();
      var done = false;
      stream.listen((_) {}, onDone: () => done = true);

      setting.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(done, isTrue);
      expect(setting.asStream, throwsA(isA<StateError>()));

      var listenedAfterDispose = false;
      stream.listen((_) {}, onDone: () => listenedAfterDispose = true);
      await Future<void>.delayed(Duration.zero);
      expect(listenedAfterDispose, isTrue, reason: 'a stream taken earlier ends once the setting is disposed');
    });
  });

  group('nullable settings', () {
    test('defaultValue falls back when storage is empty', () {
      final setting = IntNullableSetting(storage: storage, key: 'k', defaultValue: 3);
      expect(setting.value, 3);
      expect(setting.isDefault, isTrue);
    });

    test('writing null stores an explicit null, distinct from the default', () {
      final setting = IntNullableSetting(storage: storage, key: 'k', defaultValue: 3);
      setting.value = 42;
      expect(storage.getInt('k'), 42);

      setting.value = null;

      expect(storage.hasNull('k'), isTrue);
      expect(storage.getInt('k'), isNull);
      expect(setting.value, isNull);
      expect(setting.isDefault, isFalse);
    });

    test('explicit null survives invalidate and a fresh instance', () {
      final setting = IntNullableSetting(storage: storage, key: 'k', defaultValue: 3);
      setting.value = null;

      setting.invalidate();
      expect(setting.value, isNull);

      final reread = IntNullableSetting(storage: storage, key: 'k', defaultValue: 3);
      expect(reread.value, isNull);
    });

    test('reset clears an explicit null and returns to defaultValue', () {
      final setting = IntNullableSetting(storage: storage, key: 'k', defaultValue: 3);
      setting.value = null;

      setting.reset();

      expect(storage.hasNull('k'), isFalse);
      expect(setting.value, 3);
      expect(setting.isDefault, isTrue);
    });

    test('a typed write replaces an explicit null', () {
      final setting = IntNullableSetting(storage: storage, key: 'k', defaultValue: 3);
      setting.value = null;
      setting.value = 5;

      expect(storage.hasNull('k'), isFalse);
      expect(storage.getInt('k'), 5);
      setting.invalidate();
      expect(setting.value, 5);
    });

    test('explicit null rejected by the invariant falls back to defaultValue', () {
      storage.setNull('k');
      final setting = IntNullableSetting(
        storage: storage,
        key: 'k',
        defaultValue: 3,
        validator: SettingValidator((v) => v == null ? const RequiredValidationError() : null),
      );

      expect(setting.value, 3);
      expect(observer.messages.single, contains('Validation failed on read'));
    });

    test('non-nullable setting treats an explicit null as absent', () {
      storage.setNull('k');
      expect(intSetting().value, 7);
    });
  });

  group('EnumSetting', () {
    test('round-trips by enum name and falls back to defaultValue on unknown raw', () {
      final setting = EnumSetting<TestEnum>(
        storage: storage,
        key: 'k',
        defaultValue: TestEnum.a,
        values: TestEnum.values,
      );
      setting.value = TestEnum.b;
      expect(storage.getString('k'), 'b');
      setting.dispose();

      storage.setString('k', 'legacy_value');
      final reread = EnumSetting<TestEnum>(
        storage: storage,
        key: 'k',
        defaultValue: TestEnum.a,
        values: TestEnum.values,
      );
      expect(reread.value, TestEnum.a);
      expect(observer.messages.single, contains('legacy_value'));
    });
  });

  group('composition', () {
    test('a custom type is a StoredSetting with a codec, no subclass needed', () {
      final setting = StoredSetting<Point, String>(
        slot: KeyedSettingSlot.ofString(storage, key: 'k'),
        defaultValue: const Point(0, 0),
        codec: const PointCodec(),
      );

      setting.value = const Point(1, 2);
      expect(storage.getString('k'), '1,2');

      setting.invalidate();
      expect(setting.value, const Point(1, 2));
    });

    test('StoredNullableSetting wraps a non-null codec and handles null itself', () {
      final setting = StoredNullableSetting<Point, String>(
        slot: KeyedSettingSlot.ofString(storage, key: 'k'),
        codec: const PointCodec(),
      );

      setting.value = const Point(1, 2);
      expect(storage.getString('k'), '1,2');

      setting.value = null;
      expect(storage.hasNull('k'), isTrue);
      setting.invalidate();
      expect(setting.value, isNull);
    });

    test('custom equality drives deduplication and isDefault', () {
      var compared = 0;
      final setting = StoredSetting<Point, String>(
        slot: KeyedSettingSlot.ofString(storage, key: 'k'),
        defaultValue: const Point(0, 0),
        codec: const PointCodec(),
        equality: (a, b) {
          compared++;
          return a.x == b.x; // y is ignored on purpose
        },
      );

      expect(setting.isDefault, isTrue);
      setting.value = const Point(0, 99);
      expect(setting.isDefault, isTrue, reason: 'equal under the custom equality');
      expect(compared, greaterThan(0));
    });

    test('encode failure propagates and leaves cache and storage untouched', () {
      final setting = ListSetting<Object>(
        storage: storage,
        key: 'k',
        defaultValue: const [],
        fromJson: (e) => e!,
        toJson: (e) => e,
        // DateTime is not JSON-encodable,
      );
      var notifications = 0;
      setting.addListener(() => notifications++);

      expect(() => setting.value = [DateTime(2020)], throwsA(isA<JsonUnsupportedObjectError>()));

      expect(storage.getString('k'), isNull);
      expect(setting.value, isEmpty);
      expect(notifications, 0);
    });
  });

  group('built-in codecs', () {
    test('DateTimeMillisCodec round-trips at millisecond precision', () {
      const codec = DateTimeMillisCodec();
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000123);
      expect(codec.decode(codec.encode(now)), now);
    });

    test('DateTimeMillisCodec rejects out-of-range millis with a FormatException, not a RangeError', () {
      const codec = DateTimeMillisCodec();
      expect(codec.decode(8640000000000000), isA<DateTime>());
      expect(() => codec.decode(8640000000000001), throwsFormatException);
      expect(() => codec.decode(-8640000000000001), throwsFormatException);
    });

    test('DurationMillisCodec round-trips and drops sub-millisecond precision', () {
      const codec = DurationMillisCodec();
      expect(
        codec.decode(codec.encode(const Duration(seconds: 3, milliseconds: 4))),
        const Duration(seconds: 3, milliseconds: 4),
      );
      expect(codec.decode(codec.encode(const Duration(microseconds: 1500))), const Duration(milliseconds: 1));
    });

    test('EnumNameCodec round-trips by name and rejects unknown names', () {
      final codec = EnumNameCodec(TestEnum.values);
      expect(codec.encode(TestEnum.b), 'b');
      expect(codec.decode('b'), TestEnum.b);
      expect(() => codec.decode('c'), throwsFormatException);
    });

    test('UriStringCodec round-trips and rejects unparsable strings', () {
      const codec = UriStringCodec();
      final uri = Uri.parse('https://example.com/a?b=1#c');
      expect(codec.decode(codec.encode(uri)), uri);
      expect(() => codec.decode('::not a uri::'), throwsFormatException);
    });

    test('JsonListCodec rejects non-array JSON', () {
      final codec = JsonListCodec<int>(fromJson: (e) => e! as int, toJson: (e) => e);
      expect(codec.decode(codec.encode([1, 2])), [1, 2]);
      expect(() => codec.decode('{"a":1}'), throwsFormatException);
      expect(() => codec.decode('not json'), throwsFormatException);
    });
  });

  group('snapshot', () {
    test('is applied to assigned, read and default values', () {
      final setting = StoredSetting<Point, String>(
        slot: KeyedSettingSlot.ofString(storage, key: 'k'),
        defaultValue: const Point(0, 0),
        codec: const PointCodec(),
        snapshot: (p) => _CopiedPoint(p.x, p.y),
      );

      expect(setting.value, isA<_CopiedPoint>(), reason: 'default');
      setting.value = const Point(1, 1);
      expect(setting.value, isA<_CopiedPoint>(), reason: 'assigned');
      setting.invalidate();
      expect(setting.value, isA<_CopiedPoint>(), reason: 'read');
      expect(setting.value, const Point(1, 1));
    });
  });

  group('ListSetting value isolation', () {
    test('value is unmodifiable and detached from the assigned list', () {
      final setting = IntListSetting(storage: storage, key: 'k', defaultValue: const []);
      final assigned = [1, 2];

      setting.value = assigned;
      assigned.add(3);

      expect(setting.value, [1, 2]);
      expect(() => setting.value.add(4), throwsUnsupportedError);
    });

    test('elements are decoded from the stored JSON, not taken from the caller', () {
      final setting = ListSetting<Map<String, Object?>>(
        storage: storage,
        key: 'k',
        defaultValue: const [],
        fromJson: (json) => json! as Map<String, Object?>,
        toJson: (element) => element,
      );
      final element = <String, Object?>{'a': 1};

      setting.value = [element];
      element['a'] = 2;

      expect(setting.value.single, isNot(same(element)));
      expect(setting.value.single['a'], 1);
    });

    test('snapshotElement makes mutable elements unmodifiable', () {
      final setting = ListSetting<Map<String, Object?>>(
        storage: storage,
        key: 'k',
        defaultValue: const [],
        fromJson: (json) => json! as Map<String, Object?>,
        toJson: (element) => element,
        snapshotElement: freezeJsonMap,
      );
      final element = <String, Object?>{
        'a': 1,
        'nested': [1, 2],
      };

      setting.value = [element];
      element['a'] = 2;
      (element['nested']! as List<int>).add(3);

      expect(setting.value.single, {
        'a': 1,
        'nested': [1, 2],
      });
      expect(() => setting.value.single['a'] = 3, throwsUnsupportedError);
      expect(() => (setting.value.single['nested']! as List<Object?>).add(4), throwsUnsupportedError);

      setting.invalidate();
      expect(setting.value.single['a'], 1, reason: 'the stored value is the snapshot too');
    });
  });

  group('UriSetting', () {
    test('falls back to defaultValue on an unparsable stored string', () {
      storage.setString('k', '::not a uri::');
      final setting = UriSetting(
        storage: storage,
        key: 'k',
        defaultValue: Uri.parse('https://default'),
      );
      expect(setting.value, Uri.parse('https://default'));
      expect(observer.messages.single, contains('`k`'));
    });
  });

  group('EnumNullableSetting', () {
    test('unknown stored name is reported and falls back to defaultValue', () {
      storage.setString('k', 'legacy_value');
      final setting = EnumNullableSetting<TestEnum>(
        storage: storage,
        key: 'k',
        values: TestEnum.values,
        defaultValue: TestEnum.a,
      );
      expect(setting.value, TestEnum.a);
      expect(observer.messages.single, contains('legacy_value'));
    });
  });

  group('IntListSetting elements', () {
    IntListSetting listSetting() => IntListSetting(
      storage: storage,
      key: 'k',
      defaultValue: const [9],
    );

    test('integral doubles are read as integers', () {
      storage.setString('k', '[1, 2.0, -3.0]');
      expect(listSetting().value, [1, 2, -3]);
      expect(observer.events, isEmpty);
    });

    test('a null, fractional or non-numeric element rejects the whole list with a FormatException', () {
      for (final corrupt in ['[1, null]', '[1.5]', '["1"]', '[true]']) {
        storage.setString('k', corrupt);
        observer.events.clear();
        expect(listSetting().value, [9], reason: corrupt);
        expect(
          observer.events.single,
          isA<DecodeFallbackEvent>().having((e) => e.error, 'error', isA<FormatException>()),
          reason: corrupt,
        );
      }
    });
  });

  group('StringListSetting elements', () {
    test('a non-string element rejects the whole list with a FormatException', () {
      storage.setString('k', '["a", 1]');
      final setting = StringListSetting(
        storage: storage,
        key: 'k',
        defaultValue: const ['d'],
      );

      expect(setting.value, ['d']);
      expect(
        observer.events.single,
        isA<DecodeFallbackEvent>().having((e) => e.error, 'error', isA<FormatException>()),
      );
    });
  });

  group('ListSetting', () {
    test('content equality deduplicates writes', () {
      final setting = IntListSetting(storage: storage, key: 'k', defaultValue: const []);
      setting.value = [1, 2];
      var written = 0;
      storage.addKeyListener('k', () => written++);
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = [1, 2]; // equal content, different instance

      expect(notifications, 0);
      expect(written, 0);
    });

    test('round-trips through JSON and recovers defaultValue from corrupt data', () {
      final setting = IntListSetting(storage: storage, key: 'k', defaultValue: const []);
      setting.value = [3, 4];

      final reread = IntListSetting(storage: storage, key: 'k', defaultValue: const []);
      expect(reread.value, [3, 4]);

      storage.setString('k', 'not json');
      final corrupt = IntListSetting(
        storage: storage,
        key: 'k',
        defaultValue: const [9],
      );
      expect(corrupt.value, [9]);
    });
  });
}

enum TestEnum { a, b }
