import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:test/test.dart';
import 'package:typed_settings/src/storage/string_backed_storage.dart';
import 'package:typed_settings/src/storage_kit/pending_operations.dart';
import 'package:typed_settings/src/storage_kit/scalar_string_encoding.dart';
import 'package:typed_settings/typed_settings.dart';

void main() {
  const delay = Duration(milliseconds: 500);

  test('a non-positive persistenceDelay is rejected', () {
    expect(() => _RecordingBackend(persistenceDelay: Duration.zero), throwsArgumentError);
    expect(
      () => _RecordingBackend(persistenceDelay: const Duration(milliseconds: -1)),
      throwsArgumentError,
    );
  });

  test('listeners see each value at once, and the backend receives the last one after the pause', () {
    fakeAsync((async) {
      final backend = _RecordingBackend(persistenceDelay: delay);
      final setting = IntSetting(storage: backend, key: 'volume', defaultValue: 0);
      final seen = <int>[];
      setting.addListener(() => seen.add(setting.value));

      setting.value = 1;
      setting.value = 2;

      expect(seen, [1, 2]);
      expect(setting.value, 2);
      expect(backend.writes, isEmpty);

      async.elapse(delay);

      expect(backend.writes, ['volume=${encodeStoredInt(2)}']);
    });
  });

  test('a write of another key is held by the same delay', () {
    fakeAsync((async) {
      final backend = _RecordingBackend(persistenceDelay: delay);
      final volume = IntSetting(storage: backend, key: 'volume', defaultValue: 0);
      final other = IntSetting(storage: backend, key: 'other', defaultValue: 0);
      volume.addListener(() => other.value = 9);

      volume.value = 1;

      expect(other.value, 9);
      expect(backend.writes, isEmpty);

      async.elapse(delay);

      expect(backend.writes, ['volume=${encodeStoredInt(1)}', 'other=${encodeStoredInt(9)}']);
    });
  });

  test('flush persists the held value without sitting the delay out', () {
    fakeAsync((async) {
      final backend = _RecordingBackend(persistenceDelay: delay);
      final setting = IntSetting(storage: backend, key: 'volume', defaultValue: 0);
      setting.value = 4;

      var flushed = false;
      unawaited(backend.flush().then((_) => flushed = true));
      async.flushMicrotasks();

      expect(flushed, isTrue);
      expect(backend.writes, ['volume=${encodeStoredInt(4)}']);
    });
  });

  test('commit persists at once and replaces the write still waiting', () {
    fakeAsync((async) {
      final backend = _RecordingBackend(persistenceDelay: delay);
      final setting = IntSetting(storage: backend, key: 'volume', defaultValue: 0);
      setting.value = 1;

      var committed = false;
      unawaited(setting.commit(4).then((_) => committed = true));
      async.flushMicrotasks();

      expect(committed, isTrue);
      expect(setting.value, 4);
      expect(backend.writes, ['volume=${encodeStoredInt(4)}']);
    });
  });

  test('a write that replaces one a flush started is not held again, so the flush is not starved', () {
    fakeAsync((async) {
      final pending = PendingOperations();
      final inFlight = Completer<void>();
      final ran = <int>[];
      void settled(int sequence, OperationFailure? failure) {}

      pending.enqueue('k', () => inFlight.future, settled);
      pending.enqueue('k', () async => ran.add(1), settled, delay: delay);
      var flushed = false;
      unawaited(pending.wait().then((_) => flushed = true));
      pending.enqueue('k', () async => ran.add(2), settled, delay: delay);
      inFlight.complete();
      async.flushMicrotasks();

      expect(ran, [2]);
      expect(flushed, isTrue);
    });
  });
}

final class _RecordingBackend extends StringBackedStorage {
  _RecordingBackend({super.persistenceDelay}) : super(cache: {});

  final List<String> writes = [];

  @override
  Future<Map<String, String>> loadRaw() async => {};

  @override
  Future<void> writeRaw(String key, String value) async {
    writes.add('$key=$value');
  }

  @override
  Future<void> deleteRaw(String key) async {}
}
