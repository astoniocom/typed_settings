import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_backend.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

/// Reads and writes an int negated, so the value and raw types match
/// `IntSetting` and the representation does not.
class _NegatingCodec implements SettingCodec<int, int> {
  const _NegatingCodec();

  @override
  int decode(int raw) => -raw;

  @override
  int encode(int value) => -value;
}

void main() {
  group('KeyedSettingSlot', () {
    test('rejects legacy keys that contain the key', () {
      expect(
        () => KeyedSettingSlot.ofInt(InMemoryStorage(), key: 'k', legacyKeys: const ['old', 'k']),
        throwsA(isA<ArgumentError>().having((error) => error.name, 'name', 'legacyKeys')),
      );
    });

    test('joins the registry of the shared box under its key', () {
      final box = InMemoryStorage();
      final keyed = KeyedSettingSlot.ofInt(box, key: 'k', legacyKeys: const ['old']);
      final setting = IntSetting.inSlot(keyed, defaultValue: 0);

      expect(setting.diagnosticKey, 'k');
      expect(keyed.legacyKeys, ['old']);
      expect(
        BoolNullableSetting(storage: box, key: 'flag', defaultValue: false).diagnosticKey,
        'flag',
        reason: 'a nullable setting names the keyed slot it was given, not the null wrapper',
      );
      expect(SettingsRegistry.of(box)['k'], same(setting));
      expect(
        () => StringSetting.inSlot(KeyedSettingSlot.ofString(box, key: 'k'), defaultValue: ''),
        throwsStateError,
        reason: 'another slot over the same key of the box meets the setting there',
      );
    });

    group('with legacy keys', () {
      late InMemoryStorage storage;
      late KeyedSettingSlot<int> slot;
      late List<String> changed;

      setUp(() {
        storage = InMemoryStorage();
        slot = KeyedSettingSlot.ofInt(storage, key: 'k', legacyKeys: const ['old', 'older']);
        changed = [];
        for (final key in ['k', 'old', 'older']) {
          storage.addKeyListener(key, () => changed.add(key));
        }
      });

      test('reads the key when it holds anything, an explicit null included', () {
        storage
          ..setInt('old', 1)
          ..setNull('k');

        expect(slot.read(), const NullSlotState<int>());
      });

      test('falls back to the first legacy key holding anything, most recent first', () {
        storage
          ..setInt('older', 2)
          ..setInt('old', 1);
        expect(slot.read(), const RawSlotState<int>(1, fromLegacyKey: true));

        storage.remove('old');
        expect(slot.read(), const RawSlotState<int>(2, fromLegacyKey: true));

        storage.setNull('old');
        expect(slot.read(), const NullSlotState<int>(fromLegacyKey: true));
      });

      test('reads as absent when no key holds anything', () {
        expect(slot.read(), const AbsentSlotState<int>());
      });

      test('reads a value of another type as absent, and the storage reports it', () {
        final observer = RecordingObserver();
        final reporting = InMemoryStorage(observer: observer)..setString('k', 'text');

        expect(KeyedSettingSlot.ofInt(reporting, key: 'k').read(), const AbsentSlotState<int>());
        expect(observer.events.single, isA<StorageReadErrorEvent>());
      });

      test('a write moves the value: it stores the key, and removes the legacy keys that hold something once it '
          'has persisted', () async {
        storage.setInt('older', 2);
        changed.clear();

        slot.write(3);
        expect(storage.contents, {'older': 2, 'k': 3});

        await pumpEventQueue();
        expect(storage.contents, {'k': 3});
        expect(changed, ['k', 'older']);
      });

      test('an explicit null moves the same way', () async {
        storage.setInt('old', 1);

        slot.writeNull();
        await pumpEventQueue();

        expect(storage.contents, {'k': null});
      });

      test('a write that does not persist leaves the legacy keys for the next start', () async {
        final failing = _FailingStorage(cache: {'old': 'i1'}, observer: RecordingObserver());
        final slot = KeyedSettingSlot.ofInt(failing, key: 'k', legacyKeys: const ['old']);

        slot.write(3);
        await pumpEventQueue();

        expect(failing.cache.keys, ['old', 'k'], reason: 'the legacy value is still there for the next start');
      });

      test('a commit removes the legacy keys once the key has persisted', () async {
        storage.setInt('old', 1);

        final committing = slot.commit(3);
        expect(storage.contents, {'k': 3, 'old': 1}, reason: 'the key is not known to be persisted yet');

        await committing;
        expect(storage.contents, {'k': 3});
      });

      test('a commit keeps the legacy keys when the storage is closed before the key has persisted', () async {
        storage.setInt('old', 1);

        final committing = slot.commit(3);
        final closing = storage.close();

        await committing;
        await closing;
        expect(storage.contents, {'k': 3, 'old': 1}, reason: 'the key reads first, so the legacy value is harmless');
      });

      test('remove removes the key and the legacy keys, and touches nothing when nothing is stored', () {
        slot.remove();
        expect(changed, isEmpty);

        storage
          ..setInt('k', 3)
          ..setNull('old');
        changed.clear();

        slot.remove();

        expect(storage.contents, isEmpty);
        expect(changed, ['old', 'k'], reason: 'the legacy keys go first, so an older value cannot resurface');
      });

      test('remove on a storage that batches persists the removals together, the legacy keys first', () async {
        final batching = _BatchRecordingStorage(cache: {'k': 'i3', 'old': 'i1'});
        final slot = KeyedSettingSlot.ofInt(batching, key: 'k', legacyKeys: const ['old']);

        slot.remove();
        await batching.flush();

        expect(batching.batches, [
          ['old', 'k'],
        ]);
      });

      test('keeps its own copy of the legacy keys', () {
        final legacyKeys = ['old'];
        final slot = KeyedSettingSlot.ofInt(storage, key: 'k', legacyKeys: legacyKeys);
        legacyKeys.add('older');
        storage.setInt('older', 2);

        expect(slot.legacyKeys, ['old']);
        expect(slot.read(), const AbsentSlotState<int>());
      });
    });
  });

  group('a slot with no key', () {
    test('reports a listener that throws as an error of a slot listener, with no key', () {
      final observer = RecordingObserver();
      final slot = InMemorySettingSlot<int>(observer: observer);
      var later = 0;
      slot
        ..addListener(() => throw StateError('bug'))
        ..addListener(() => later++)
        ..write(1);

      expect(later, 1);
      expect(
        observer.events.single,
        isA<ListenerErrorEvent>()
            .having((event) => event.source, 'source', ListenerSource.slot)
            .having((event) => event.key, 'key', isNull),
      );
    });

    test('a listener removed by another during a notification is not called by it', () {
      final slot = InMemorySettingSlot<int>();
      var removedCalls = 0;
      void removed() => removedCalls++;
      slot
        ..addListener(() => slot.removeListener(removed))
        ..addListener(removed)
        ..write(1);

      expect(removedCalls, 0);
    });

    test('a listener added during a notification is first called on the next change', () {
      final slot = InMemorySettingSlot<int>();
      var addedCalls = 0;
      var added = false;
      slot.addListener(() {
        if (added) return;
        added = true;
        slot.addListener(() => addedCalls++);
      });

      slot.write(1);
      expect(addedCalls, 0);

      slot.write(2);
      expect(addedCalls, 1);
    });

    test('holds one value, and remove of an absent value does not notify', () {
      final storage = InMemorySettingSlot<int>();
      var notifications = 0;
      storage.addListener(() => notifications++);

      expect(storage.read(), const AbsentSlotState<int>());

      storage.remove();
      expect(notifications, 0);

      storage.write(4);
      expect(storage.read(), const RawSlotState<int>(4));
      storage.writeNull();
      expect(storage.read(), const NullSlotState<int>());
      storage.remove();
      expect(storage.read(), const AbsentSlotState<int>());
      expect(notifications, 3);
    });

    test('is the slot of a setting, which names no key', () async {
      final storage = InMemorySettingSlot<bool>();
      final setting = BoolSetting.inSlot(storage, defaultValue: false);
      var notifications = 0;
      setting.addListener(() => notifications++);

      expect(setting.diagnosticKey, isNull);
      expect(setting.value, isFalse);
      expect(setting.hasStoredValue, isFalse);
      expect(storage.place, isA<KeylessSlotPlace>().having((place) => place.slot, 'slot', same(storage)));

      setting.value = true;
      expect(notifications, 1);
      expect(storage.read(), const RawSlotState<bool>(true));

      await setting.commit(true);
      setting.reset();
      expect(setting.value, isFalse);
      expect(setting.hasStoredValue, isFalse);
      expect(notifications, 2);
    });

    test('keeps two settings over it coherent', () {
      final storage = InMemorySettingSlot<bool>();
      final first = BoolSetting.inSlot(storage, defaultValue: false);
      final second = BoolSetting.inSlot(storage, defaultValue: false);
      expect(second.value, isFalse, reason: 'a cold setting has nothing cached to compare a later change with');
      var notifications = 0;
      second.addListener(() => notifications++);

      first.value = true;

      expect(second.value, isTrue);
      expect(notifications, 1);
    });

    test('rejects a second setting that reads the same slot differently', () {
      final storage = InMemorySettingSlot<int>();
      final first = StoredSetting<int, int>(slot: storage, defaultValue: 0, codec: const IdentityCodec());

      expect(
        () => StoredSetting<int, int>(slot: storage, defaultValue: 0, codec: const _NegatingCodec()),
        throwsA(
          isA<StateError>().having((error) => error.message, 'message', contains('This slot holds a live setting')),
        ),
      );

      first.value = 2;
      first.dispose();
      final second = StoredSetting<int, int>(slot: storage, defaultValue: 1, codec: const _NegatingCodec());
      expect(second.value, -2, reason: 'the raw 2 left by the first setting is decoded by the new codec');
    });

    test('stores an explicit null apart from nothing stored', () {
      final setting = BoolNullableSetting.inSlot(InMemorySettingSlot<bool>(), defaultValue: false);

      expect(setting.value, isFalse);
      expect(setting.hasStoredValue, isFalse);

      setting.value = null;

      expect(setting.value, isNull);
      expect(setting.hasStoredValue, isTrue);

      setting.reset();
      expect(setting.value, isFalse);
      expect(setting.hasStoredValue, isFalse);
    });
  });
}

/// A string-backed storage that records the deletions of each batch it
/// persists.
final class _BatchRecordingStorage extends StringBackedStorage {
  _BatchRecordingStorage({required super.cache});

  @override
  Future<Map<String, String>> loadRaw() async => {};

  final List<List<String>> batches = [];

  @override
  Future<void> writeBatchRaw(Map<String, String> upserts, Iterable<String> deletes) async =>
      batches.add(List.of(deletes));

  @override
  Future<void> writeRaw(String key, String value) async {}

  @override
  Future<void> deleteRaw(String key) async {}
}

/// A string-backed storage whose writes never reach the backend; [cache]
/// is its in-memory state.
final class _FailingStorage extends StringBackedStorage {
  _FailingStorage({required this.cache, super.observer}) : super(cache: cache);

  @override
  Future<Map<String, String>> loadRaw() async => {};

  final Map<String, String> cache;

  @override
  Future<void> writeRaw(String key, String value) async => throw StateError('disk full');

  @override
  Future<void> deleteRaw(String key) async {}
}
