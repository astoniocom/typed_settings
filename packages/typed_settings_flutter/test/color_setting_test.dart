import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';

void main() {
  const black = Color(0xFF000000);
  const translucent = Color(0x80123456);

  late InMemoryStorage storage;

  setUp(() => storage = InMemoryStorage());

  test('ColorArgbCodec round-trips ARGB', () {
    const codec = ColorArgbCodec();
    expect(codec.decode(codec.encode(translucent)), translucent);
  });

  test('ColorSetting holds a Display P3 color as the sRGB color it stores', () {
    const p3 = Color.from(alpha: 1, red: 0.8, green: 0.4, blue: 0.2, colorSpace: ColorSpace.displayP3);
    final srgb = p3.withValues(colorSpace: ColorSpace.extendedSRGB).toARGB32();
    expect(
      srgb,
      isNot(const Color.from(alpha: 1, red: 0.8, green: 0.4, blue: 0.2).toARGB32()),
      reason: 'the conversion changes the components',
    );

    final setting = ColorSetting(storage: storage, key: 'k', defaultValue: black)..value = p3;

    expect(storage.getInt('k'), srgb);
    expect(setting.value, Color(srgb));
    setting.invalidate();
    expect(setting.value, Color(srgb), reason: 'the same value is read after a restart');
  });

  test('ColorArgbCodec clamps a Display P3 color outside the sRGB gamut', () {
    const p3Red = Color.from(alpha: 1, red: 1, green: 0, blue: 0, colorSpace: ColorSpace.displayP3);

    expect(const ColorArgbCodec().encode(p3Red), 0xFFFF0000);
  });

  test('ColorSetting stores the ARGB int and a fresh instance reads it back', () {
    ColorSetting(storage: storage, key: 'k', defaultValue: black).value = translucent;

    expect(storage.getInt('k'), 0x80123456);
    final reread = ColorSetting(storage: storage, key: 'k', defaultValue: black);
    expect(reread.value, translucent);
    expect(reread.isDefault, isFalse);
  });

  test('ColorNullableSetting persists an explicit null distinct from the default', () {
    final setting = ColorNullableSetting(storage: storage, key: 'k', defaultValue: black)..value = null;

    expect(setting.value, isNull);
    expect(storage.hasNull('k'), isTrue);
    expect(ColorNullableSetting(storage: storage, key: 'k', defaultValue: black).value, isNull);

    setting.reset();
    expect(setting.value, black);
  });

  test('the Color presets take every option of StoredSetting and honour legacy keys', () {
    storage.setInt('old', 0x80123456);
    final validator = SettingValidator<Color>((_) => null);

    final setting = ColorSetting(
      storage: storage,
      key: 'new',
      legacyKeys: const ['old'],
      defaultValue: black,
      validator: validator,
    );
    expect(setting.value, translucent);
    setting.dispose();

    final nullable = ColorNullableSetting(
      storage: storage,
      key: 'new',
      legacyKeys: const ['old'],
      validator: SettingValidator<Color?>((_) => null),
    );
    expect(nullable.value, translucent);
  });
}
