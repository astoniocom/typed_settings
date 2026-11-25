import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

/// Counts key listener registrations, to show a rejected setting left none.
final class _CountingStorage extends InMemoryStorage {
  int addKeyListenerCalls = 0;

  @override
  void addKeyListener(String key, void Function() listener) {
    addKeyListenerCalls++;
    super.addKeyListener(key, listener);
  }
}

/// Reads and writes an int negated: the same value and raw types as
/// `IntSetting`, another representation.
class _NegatingCodec implements SettingCodec<int, int> {
  const _NegatingCodec();

  @override
  int decode(int raw) => -raw;

  @override
  int encode(int value) => -value;
}

enum _Theme { light, dark }

void main() {
  late _CountingStorage storage;
  late SettingsRegistry registry;

  setUp(() {
    storage = _CountingStorage();
    registry = SettingsRegistry.of(storage);
  });

  group('settings that disagree on how a key is stored', () {
    test('are rejected with a StateError before they touch the storage', () {
      final count = IntSetting(storage: storage, key: 'x', defaultValue: 0);
      final listeners = storage.addKeyListenerCalls;

      expect(
        () => StringSetting(storage: storage, key: 'x', defaultValue: ''),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains('`x`'), contains('int'), contains('String')),
          ),
        ),
      );

      expect(storage.addKeyListenerCalls, listeners, reason: 'the rejected setting registered no listener');
      expect(registry.settings, [count]);
    });

    test('include a nullable and a non-nullable setting of one type', () {
      IntSetting(storage: storage, key: 'x', defaultValue: 0);

      expect(() => IntNullableSetting(storage: storage, key: 'x'), throwsStateError);
    });

    test('include the same value and raw types read through another codec, nullable or not', () {
      StoredSetting<int, int>(
        slot: KeyedSettingSlot.ofInt(storage, key: 'x'),
        defaultValue: 0,
        codec: const IdentityCodec(),
      );
      StoredNullableSetting<int, int>(
        slot: KeyedSettingSlot.ofInt(storage, key: 'y'),
        codec: const IdentityCodec(),
      );

      expect(
        () => StoredSetting<int, int>(
          slot: KeyedSettingSlot.ofInt(storage, key: 'x'),
          defaultValue: 0,
          codec: const _NegatingCodec(),
        ),
        throwsStateError,
      );
      expect(
        () => StoredNullableSetting<int, int>(
          slot: KeyedSettingSlot.ofInt(storage, key: 'y'),
          codec: const _NegatingCodec(),
        ),
        throwsStateError,
      );
    });
  });

  group('settings that agree on how a key is stored', () {
    test('share it, and the registry lists the key once, by its first setting', () {
      final first = IntSetting(storage: storage, key: 'x', defaultValue: 0);
      final second = IntSetting(storage: storage, key: 'x', defaultValue: 0);

      expect(registry.settings, [first]);
      expect(registry['x'], same(first));
      second.value = 5;
      expect(first.value, 5);
    });

    test('include instances that differ in their enum legacy names', () {
      EnumSetting<_Theme>(storage: storage, key: 'theme', defaultValue: _Theme.light, values: _Theme.values);
      EnumSetting<_Theme>(
        storage: storage,
        key: 'theme',
        defaultValue: _Theme.light,
        values: _Theme.values,
        legacyNames: const {'night': _Theme.dark},
      );

      expect(registry['theme'], isNotNull);
      expect(registry.settings, hasLength(1));
    });
  });

  test('instances over one key that differ in their legacy keys are rejected, since they would read differently', () {
    IntSetting(storage: storage, key: 'new', legacyKeys: const ['old'], defaultValue: 0);

    expect(() => IntSetting(storage: storage, key: 'new', defaultValue: 0), throwsStateError);
    expect(
      () => IntSetting(storage: storage, key: 'new', legacyKeys: const ['older', 'old'], defaultValue: 0),
      throwsStateError,
      reason: 'the order decides which legacy key is read first',
    );
    expect(() => IntSetting(storage: storage, key: 'new', legacyKeys: const ['old'], defaultValue: 0), returnsNormally);
  });

  group('legacy keys that collide with another live setting are rejected', () {
    test('a legacy key that is the key of a live setting', () {
      IntSetting(storage: storage, key: 'a', defaultValue: 0);

      expect(() => IntSetting(storage: storage, key: 'b', legacyKeys: const ['a'], defaultValue: 0), throwsStateError);
    });

    test('a key that a live setting lists as legacy', () {
      IntSetting(storage: storage, key: 'b', legacyKeys: const ['a'], defaultValue: 0);

      expect(() => IntSetting(storage: storage, key: 'a', defaultValue: 0), throwsStateError);
    });

    test('a legacy key that a live setting lists as well', () {
      IntSetting(storage: storage, key: 'b', legacyKeys: const ['old'], defaultValue: 0);

      expect(
        () => IntSetting(storage: storage, key: 'c', legacyKeys: const ['old'], defaultValue: 0),
        throwsStateError,
      );
    });
  });

  group('disposal', () {
    test('frees the key for a setting of another type', () {
      IntSetting(storage: storage, key: 'x', defaultValue: 0).dispose();

      final text = StringSetting(storage: storage, key: 'x', defaultValue: '');

      expect(registry.settings, [text]);
    });

    test('hands the key on to the next setting sharing it, and drops it with the last one', () {
      final first = IntSetting(storage: storage, key: 'x', defaultValue: 0);
      final second = IntSetting(storage: storage, key: 'x', defaultValue: 0);

      first.dispose();
      expect(registry['x'], same(second));

      second.dispose();
      expect(registry['x'], isNull);
      expect(registry.settings, isEmpty);
    });
  });

  test('lists the live settings in the order their keys came into use, separately per storage', () {
    final other = InMemoryStorage();
    final b = IntSetting(storage: storage, key: 'b', defaultValue: 0);
    final a = StringSetting(storage: storage, key: 'a', defaultValue: '');
    final elsewhere = StringSetting(storage: other, key: 'b', defaultValue: '');

    expect(registry.settings, [b, a]);
    expect(SettingsRegistry.of(other).settings, [elsewhere], reason: 'another storage may use `b` for another type');
    expect(SettingsRegistry.of(storage), registry);
    expect(SettingsRegistry.of(other), isNot(registry));
  });

  test('lists settings of every type as Setting<Object?>: they can be reset and read together', () {
    final count = IntSetting(storage: storage, key: 'count', defaultValue: 0)..value = 3;
    final theme = EnumSetting(storage: storage, key: 'theme', values: _Theme.values, defaultValue: _Theme.light)
      ..value = _Theme.dark;

    expect(
      {for (final setting in registry.settings) setting.diagnosticKey: setting.value},
      {'count': 3, 'theme': _Theme.dark},
    );

    for (final setting in registry.settings) {
      setting.reset();
    }
    expect([count.value, theme.value], [0, _Theme.light]);
    expect(storage.keys, isEmpty);
  });

  test('a value of another type than the setting holds is rejected with a TypeError', () {
    IntSetting(storage: storage, key: 'count', defaultValue: 0);

    expect(() => registry['count']!.value = 'three', throwsA(isA<TypeError>()));
    expect(storage.keys, isEmpty);
  });
}
