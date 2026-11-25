import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

/// Throws what [fail] throws from every int read, as a storage with a bug,
/// or one used in a way it rejects, would.
final class _ThrowingStorage extends InMemoryStorage {
  _ThrowingStorage(this.fail, {super.observer});

  final Never Function() fail;

  @override
  int? getInt(String key) => fail();
}

void main() {
  late RecordingObserver observer;
  late InMemoryStorage storage;

  setUp(() {
    observer = RecordingObserver();
    storage = InMemoryStorage(observer: observer);
  });

  Matcher decodeFallback(Matcher error) => isA<DecodeFallbackEvent>()
      .having((e) => e.error, 'error', error)
      .having((e) => e.stackTrace, 'stackTrace', isNotNull);

  test('a failed cast in fromJson falls back to the default instead of making every read throw', () {
    storage.setString('k', '["a"]');
    final setting = ListSetting<int>(
      storage: storage,
      key: 'k',
      defaultValue: const [1],
      fromJson: (json) => json! as int,
      toJson: (element) => element,
    );

    expect(setting.value, [1]);
    final event = observer.events.single;
    expect(event, decodeFallback(isA<TypeError>()));
    expect(
      (event as DecodeFallbackEvent).describe(includeData: false),
      endsWith('${event.error}'),
      reason: 'the message of a TypeError names types only',
    );

    expect(storage.getString('k'), '["a"]', reason: 'reading leaves the stored value in place');
    setting.value = const [1];
    expect(storage.getString('k'), '["a"]', reason: 'writing back the default it shows keeps it as well');
    setting.value = const [2];
    expect(storage.getString('k'), '[2]', reason: 'another value replaces it');
  });

  test('an Error of the invariant on a stored value falls back to the default', () {
    storage.setInt('k', 5);
    final setting = IntSetting(
      storage: storage,
      key: 'k',
      defaultValue: 0,
      validator: SettingValidator((value) => value == 5 ? throw StateError('bug') : null),
    );

    expect(setting.value, 0);
    expect(observer.events.single, decodeFallback(isA<StateError>()));
  });

  test('an Error of the snapshot of a decoded value falls back to the default', () {
    storage.setInt('k', 5);
    final setting = StoredSetting<int, int>(
      slot: KeyedSettingSlot.ofInt(storage, key: 'k'),
      defaultValue: 0,
      codec: const IdentityCodec(),
      snapshot: (value) => value == 5 ? throw StateError('bug') : value,
    );

    expect(setting.value, 0);
    expect(observer.events.single, decodeFallback(isA<StateError>()));
  });

  test('an Error of the storage itself propagates: a default would hide the bug', () {
    final setting = IntSetting(
      storage: _ThrowingStorage(() => throw StateError('closed'), observer: observer),
      key: 'k',
      defaultValue: 0,
    );

    expect(() => setting.value, throwsStateError);
    expect(observer.events, isEmpty);
  });

  test('an exception of the storage is reported like unusable data', () {
    final setting = IntSetting(
      storage: _ThrowingStorage(() => throw const FormatException('corrupt'), observer: observer),
      key: 'k',
      defaultValue: 0,
    );

    expect(setting.value, 0);
    expect(observer.events.single, decodeFallback(isA<FormatException>()));
  });
}
