import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

class _ScreenSettings {
  _ScreenSettings(this.storage);

  final SettingsStorage storage;

  final _settings = SettingsOwner();

  void dispose() => _settings.dispose();

  late final volume = _settings.own(IntSetting(storage: storage, key: 'volume', defaultValue: 5));

  late final theme = _settings.own(StringSetting(storage: storage, key: 'theme', defaultValue: 'light'));

  late final unused = _settings.own(BoolSetting(storage: storage, key: 'unused', defaultValue: false));

  IntSetting createVolumeAgain() => _settings.own(IntSetting(storage: storage, key: 'volume', defaultValue: 5));
}

void main() {
  late InMemoryStorage storage;

  setUp(() => storage = InMemoryStorage());

  test('disposes the settings it owns together, and only those that were created', () {
    final owner = _ScreenSettings(storage);
    owner.volume.value = 7;
    owner.theme.value;

    expect(SettingsRegistry.of(storage).settings, hasLength(2));

    owner.dispose();

    expect(SettingsRegistry.of(storage).settings, isEmpty, reason: 'nothing stays registered with the storage');
    expect(() => owner.volume.value, throwsStateError);
    expect(storage.getInt('volume'), 7, reason: 'disposing a setting leaves the stored value');
    expect(
      () => StringSetting(storage: storage, key: 'volume', defaultValue: ''),
      returnsNormally,
      reason: 'the key is free for a setting of another type',
    );
  });

  test('a second dispose does nothing, and owning afterwards is a StateError', () {
    final owner = _ScreenSettings(storage)..volume;

    owner
      ..dispose()
      ..dispose();

    expect(owner.createVolumeAgain, throwsStateError);
    expect(SettingsRegistry.of(storage).settings, isEmpty, reason: 'the rejected setting was disposed');
  });

  test('a setting whose disposal throws does not leave the others registered', () {
    final owner = _ScreenSettings(storage)
      ..volume
      ..theme
      ..unused;
    // The bug this guards against: an owned setting disposed by hand. Its
    // second disposal fails an assertion, in the middle of the others.
    owner.theme.dispose();

    expect(owner.dispose, throwsA(isA<AssertionError>()), reason: 'the bug is still reported');

    expect(SettingsRegistry.of(storage).settings, isEmpty);
    expect(() => owner.volume.value, throwsStateError, reason: 'created before the one that threw');
    expect(() => owner.unused.value, throwsStateError);
    expect(owner.dispose, returnsNormally, reason: 'nothing is left to dispose');
  });
}
