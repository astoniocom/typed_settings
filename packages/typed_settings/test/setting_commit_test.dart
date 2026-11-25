import 'dart:async';

import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_backend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

/// Persists into [disk]; writes and removals wait for [gate] while it is
/// set and fail while [failing] is set.
final class _Backend extends StringBackedStorage {
  _Backend({super.observer}) : super(cache: {});

  @override
  Future<Map<String, String>> loadRaw() async => Map.of(disk);

  final Map<String, String> disk = {};
  Completer<void>? gate;
  bool failing = false;

  Future<void> _apply(void Function() change) async {
    final gate = this.gate;
    if (gate != null) await gate.future;
    if (failing) throw StateError('disk full');
    change();
  }

  @override
  Future<void> writeRaw(String key, String value) => _apply(() => disk[key] = value);

  @override
  Future<void> deleteRaw(String key) => _apply(() => disk.remove(key));
}

void main() {
  late RecordingObserver observer;
  late _Backend storage;

  setUp(() {
    observer = RecordingObserver();
    storage = _Backend(observer: observer);
  });

  test('updates memory and notifies right away, like the setter, and completes once the value is persisted', () async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 0);
    var notified = 0;
    setting.addListener(() => notified++);
    final gate = storage.gate = Completer<void>();

    var committed = false;
    final committing = setting.commit(5).then((_) => committed = true);

    expect(setting.value, 5);
    expect(notified, 1);
    await Future<void>.delayed(Duration.zero);
    expect(committed, isFalse, reason: 'the write is still held');

    gate.complete();
    await committing;
    expect(storage.disk, {'k': 'i5'});
  });

  test('fails with SettingsPersistException when the write does not persist; the value stays in memory', () async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 0);
    storage.failing = true;

    await expectLater(setting.commit(5), throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['k'])));

    expect(setting.value, 5);
    expect(observer.events.single, isA<PersistErrorEvent>().having((e) => e.key, 'key', 'k'));
  });

  test('is not failed by another key that did not persist', () async {
    final other = IntSetting(storage: storage, key: 'other', defaultValue: 0);
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 0);
    storage.failing = true;
    other.value = 1;
    await expectLater(storage.flush(), throwsA(isA<SettingsPersistException>()));

    storage.failing = false;
    await setting.commit(5);

    expect(storage.disk, {'k': 'i5'});
  });

  test('writes an equal value again without notifying, which persists a value whose earlier write failed', () async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 0);
    storage.failing = true;
    setting.value = 5;
    await expectLater(storage.flush(), throwsA(isA<SettingsPersistException>()));

    storage.failing = false;
    var notified = 0;
    setting.addListener(() => notified++);
    await setting.commit(5);

    expect(notified, 0, reason: 'the value did not change');
    expect(storage.disk, {'k': 'i5'});
    await storage.flush();
  });

  test('a value the validator rejects fails the future and changes nothing', () async {
    final setting = IntSetting(
      storage: storage,
      key: 'k',
      defaultValue: 0,
      validator: SettingValidator.range(min: 0, max: 10),
    );
    var notified = 0;
    setting.addListener(() => notified++);

    await expectLater(setting.commit(50), throwsA(isA<SettingValidationException>()));

    expect(setting.value, 0);
    expect(notified, 0);
    expect(storage.disk, isEmpty);
  });

  test('removes the legacy keys only once the value is persisted under the key', () async {
    storage.setInt('old', 1);
    await storage.flush();
    final setting = IntSetting(
      storage: storage,
      key: 'new',
      legacyKeys: const ['old'],
      defaultValue: 0,
    );

    storage.failing = true;
    await expectLater(setting.commit(2), throwsA(isA<SettingsPersistException>()));
    expect(storage.disk, {'old': 'i1'}, reason: 'the next start still reads the legacy value');

    storage.failing = false;
    await setting.commit(2);
    await storage.flush();
    expect(storage.disk, {'new': 'i2'});
  });

  test('inside a batch, waits for the write the batch hands over when it returns', () async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 0);
    late Future<void> committing;

    storage.batch(() {
      committing = setting.commit(5);
      expect(storage.disk, isEmpty, reason: 'the batch holds the write back');
    });
    await committing;

    expect(storage.disk, {'k': 'i5'});
  });

  test('inside a batch that does not persist, fails', () async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 0);
    storage.failing = true;
    late Future<void> committing;

    storage.batch(() => committing = setting.commit(5));

    await expectLater(committing, throwsA(isA<SettingsPersistException>().having((e) => e.keys, 'keys', ['k'])));
  });

  test('a nullable setting commits an explicit null', () async {
    final setting = IntNullableSetting(storage: storage, key: 'k', defaultValue: 7);

    await setting.commit(null);

    expect(setting.value, isNull);
    expect(storage.disk, {'k': 'n'});
  });

  test('completes right away on a storage that persists nothing', () async {
    final setting = IntSetting(
      storage: InMemoryStorage(),
      key: 'k',
      defaultValue: 0,
    );

    await setting.commit(5);

    expect(setting.value, 5);
  });

  test('is rejected on a disposed setting', () async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 0)..dispose();

    await expectLater(setting.commit(5), throwsStateError);
  });
}
