import 'package:meta/meta.dart';
import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

/// A storage that holds coordinates natively, in addition to the four
/// types of every storage: a preset over [_LatLonStorage] and a fake of
/// it, each written the way the library documents.
void main() {
  late RecordingObserver observer;
  late _InMemoryLatLonStorage storage;

  setUp(() {
    observer = RecordingObserver();
    storage = _InMemoryLatLonStorage(observer: observer);
  });

  test('a preset stores the type natively and reads it back', () {
    final home = _LatLonSetting(storage: storage, key: 'home', defaultValue: _origin);

    home.value = const _LatLon(52.5, 13.4);

    expect(storage.getLatLon('home'), const _LatLon(52.5, 13.4));
    expect(home.value, const _LatLon(52.5, 13.4));
    expect(home.hasStoredValue, isTrue);
  });

  test('a write through the storage reaches a setting over the key', () {
    final home = _LatLonSetting(storage: storage, key: 'home', defaultValue: _origin);
    var notifications = 0;
    home.addListener(() => notifications++);
    expect(home.value, _origin);

    storage.setLatLon('home', const _LatLon(1, 2));

    expect(home.value, const _LatLon(1, 2));
    expect(notifications, 1);
  });

  test('reads a legacy key and moves the value on the first write', () async {
    storage.setLatLon('old_home', const _LatLon(1, 2));
    final home = _LatLonSetting(storage: storage, key: 'home', defaultValue: _origin, legacyKeys: const ['old_home']);

    expect(home.value, const _LatLon(1, 2));

    home.value = const _LatLon(3, 4);
    await pumpEventQueue();
    expect(storage.keys, ['home']);
  });

  test('a value of another type reads as the default and is reported by the storage', () {
    storage.setString('home', 'Berlin');
    final home = _LatLonSetting(storage: storage, key: 'home', defaultValue: _origin);

    expect(home.value, _origin);
    expect(home.hasStoredValue, isFalse);
    expect(observer.events.whereType<StorageReadErrorEvent>(), hasLength(1));
  });

  test('a nullable setting stores null as an explicit null', () {
    final home = StoredNullableSetting<_LatLon, _LatLon>(
      slot: _latLonSlot(storage, 'home'),
      codec: const IdentityCodec(),
      defaultValue: _origin,
    );

    home.value = null;

    expect(storage.hasNull('home'), isTrue);
    expect(home.hasStoredValue, isTrue);
  });

  test('a setting of another raw type over the same key is rejected', () {
    _LatLonSetting(storage: storage, key: 'home', defaultValue: _origin);

    expect(() => StringSetting(storage: storage, key: 'home', defaultValue: ''), throwsStateError);
  });
}

const _origin = _LatLon(0, 0);

@immutable
final class _LatLon {
  const _LatLon(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  bool operator ==(Object other) => other is _LatLon && other.lat == lat && other.lon == lon;

  @override
  int get hashCode => Object.hash(lat, lon);
}

/// The interface of a storage that holds coordinates; the getter follows
/// the typed getter contract of [SettingsStorage].
abstract interface class _LatLonStorage implements SettingsStorage {
  _LatLon? getLatLon(String key);

  void setLatLon(String key, _LatLon value);
}

final class _InMemoryLatLonStorage extends InMemoryStorage implements _LatLonStorage {
  _InMemoryLatLonStorage({super.observer});

  @override
  _LatLon? getLatLon(String key) => readValue<_LatLon>(key);

  @override
  void setLatLon(String key, _LatLon value) => writeValue(key, value);
}

KeyedSettingSlot<_LatLon> _latLonSlot(_LatLonStorage storage, String key, [List<String> legacyKeys = const []]) =>
    KeyedSettingSlot(storage, key: key, getRaw: storage.getLatLon, setRaw: storage.setLatLon, legacyKeys: legacyKeys);

base class _LatLonSetting extends StoredSetting<_LatLon, _LatLon> {
  _LatLonSetting({
    required _LatLonStorage storage,
    required String key,
    required _LatLon defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<_LatLon>? validator,
  }) : this.inSlot(
         _latLonSlot(storage, key, legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  _LatLonSetting.inSlot(
    SettingSlot<_LatLon> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const IdentityCodec());
}
