import 'dart:async';

import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_backend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

final class _FailingBackend extends StringBackedStorage {
  _FailingBackend({super.observer}) : super(cache: {});

  @override
  Future<Map<String, String>> loadRaw() async => {};

  @override
  Future<void> writeRaw(String key, String value) async => throw StateError('disk full');

  @override
  Future<void> deleteRaw(String key) async {}
}

/// Runs [body] and returns the errors that reached the zone's uncaught
/// error handler.
Future<List<Object>> _captureUncaught(FutureOr<void> Function() body) async {
  final errors = <Object>[];
  final done = Completer<void>();
  unawaited(
    runZonedGuarded(() async {
      try {
        await body();
      } finally {
        done.complete();
      }
    }, (error, stackTrace) => errors.add(error)),
  );
  await done.future;
  return errors;
}

/// Runs [body] with `print` captured into the returned list.
Future<List<String>> _capturePrint(FutureOr<void> Function() body) async {
  final lines = <String>[];
  await runZoned(
    () async => body(),
    zoneSpecification: ZoneSpecification(print: (self, parent, zone, line) => lines.add(line)),
  );
  return lines;
}

void main() {
  group('default observer', () {
    // A debug build says once per isolate that a storage has no observer;
    // say it before every test, so that what a test prints is the events.
    setUp(() => _capturePrint(InMemoryStorage.new));

    test('a storage created without one holds a DefaultSettingsObserver', () {
      expect(InMemoryStorage().observer, isA<DefaultSettingsObserver>());
    });

    test('a debug build says once that a storage was created without an observer', () async {
      SettingsStorageBase.resetDefaultObserverWarning();
      final lines = await _capturePrint(() {
        InMemoryStorage(observer: const _Recording([]));
        InMemoryStorage();
        InMemoryStorage();
      });

      expect(lines, [allOf(startsWith('typed_settings: InMemoryStorage was created without an observer'))]);
    });

    test('a persist error with no observer configured is printed in one line, the stack trace logged', () async {
      final lines = await _capturePrint(() async {
        final storage = _FailingBackend()..setString('k', 'v');
        await expectLater(storage.flush(), throwsA(isA<SettingsPersistException>()));
      });

      expect(lines, [allOf(startsWith('typed_settings: '), contains('`k`'), contains('disk full'))]);
    });

    test('a read fallback with no observer configured is printed', () async {
      final lines = await _capturePrint(() {
        final storage = InMemoryStorage()..setString('k', '::not a uri::');
        final setting = UriSetting(
          storage: storage,
          key: 'k',
          defaultValue: Uri.parse('https://example.com'),
        );
        expect(setting.value, Uri.parse('https://example.com'));
      });

      expect(lines.first, allOf(startsWith('typed_settings: '), contains('`k`')));
    });

    test('the observer is fixed at construction, so another storage does not share its events', () async {
      final lines = await _capturePrint(() {
        final plain = InMemoryStorage();
        final events = <SettingsEvent>[];
        final recorded = InMemoryStorage(observer: _Recording(events))..setString('k', 'text');

        expect(recorded.getInt('k'), isNull);
        expect(events.single, isA<StorageReadErrorEvent>());

        plain.setString('k', 'text');
        expect(plain.getInt('k'), isNull);
        expect(events, hasLength(1));
        expect(plain.observer, isA<DefaultSettingsObserver>());
      });

      expect(lines, hasLength(1), reason: 'only the storage left on the default observer prints');
    });
  });

  group('report', () {
    test('hands every event to onEvent as it is, in order', () {
      final received = <SettingsEvent>[];
      final observer = _Recording(received);
      final events = <SettingsEvent>[
        DecodeFallbackEvent(key: 'k', error: const FormatException('e'), stackTrace: StackTrace.current),
        const ValidationFallbackEvent(key: 'k', error: RequiredValidationError()),
        const StorageReadErrorEvent(key: 'k', raw: 'r', error: 'e'),
        PersistErrorEvent(key: 'k', error: 'e', stackTrace: StackTrace.current),
        ListenerErrorEvent(source: ListenerSource.slot, key: null, error: 'e', stackTrace: StackTrace.current),
      ];

      events.forEach(observer.report);

      expect(received, orderedEquals(events.map(same)));
    });

    test('a forwarding observer relays through report to its targets', () {
      final received = <SettingsEvent>[];
      final storage = InMemoryStorage(observer: _Forwarding([_Recording(received)]))..setString('k', 'text');

      storage.getInt('k');

      expect(received.single, isA<StorageReadErrorEvent>());
    });
  });

  group('an observer that throws', () {
    test('does not make a read of unusable data throw; the setting falls back once', () async {
      late UriSetting setting;
      final errors = await _captureUncaught(() {
        final storage = InMemoryStorage(observer: const _Throwing())..setString('k', '::not a uri::');
        setting = UriSetting(storage: storage, key: 'k', defaultValue: Uri.parse('https://example.com'));

        expect(setting.value, Uri.parse('https://example.com'));
        expect(setting.value, Uri.parse('https://example.com'));
      });

      expect(errors, [isA<_ObserverBug>()], reason: 'reported once, then the fallback is cached');
    });

    test('does not stop a storage from notifying the rest of the key listeners', () async {
      final notified = <String>[];
      final errors = await _captureUncaught(() {
        InMemoryStorage(observer: const _Throwing())
          ..addKeyListener('k', () => throw StateError('listener bug'))
          ..addKeyListener('k', () => notified.add('second'))
          ..setInt('k', 1);
      });

      expect(notified, ['second']);
      expect(errors, [isA<_ObserverBug>()]);
    });

    test('does not stop a setting from notifying the rest of its listeners', () async {
      final notified = <String>[];
      final errors = await _captureUncaught(() {
        final setting =
            IntSetting(
                storage: InMemoryStorage(observer: const _Throwing()),
                key: 'k',
                defaultValue: 0,
              )
              ..addListener(() => throw StateError('listener bug'))
              ..addListener(() => notified.add('second'));

        setting.value = 1;
      });

      expect(notified, ['second']);
      expect(errors, [isA<_ObserverBug>()]);
    });

    test('does not keep a flush from reporting the write that did not persist', () async {
      final errors = await _captureUncaught(() async {
        final storage = _FailingBackend(observer: const _Throwing())..setString('k', 'v');
        await expectLater(storage.flush(), throwsA(isA<SettingsPersistException>()));
      });

      expect(errors, [isA<_ObserverBug>()]);
    });
  });
}

final class _ObserverBug implements Exception {
  const _ObserverBug();
}

final class _Throwing extends SettingsObserver {
  const _Throwing();

  @override
  void onEvent(SettingsEvent event) => throw const _ObserverBug();
}

final class _Recording extends SettingsObserver {
  const _Recording(this.events);
  final List<SettingsEvent> events;
  @override
  void onEvent(SettingsEvent event) => events.add(event);
}

final class _Forwarding extends SettingsObserver {
  const _Forwarding(this.targets);
  final List<SettingsObserver> targets;

  @override
  void onEvent(SettingsEvent event) {
    for (final target in targets) {
      target.report(event);
    }
  }
}
