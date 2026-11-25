import 'dart:ui';

import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings_flutter/src/codec/color_argb_codec.dart';

/// A [Color] setting, stored as its ARGB value.
base class ColorSetting extends StoredSetting<Color, int> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  ColorSetting({
    required SettingsStorage storage,
    required String key,
    required Color defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<Color>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the ARGB value.
  ColorSetting.inSlot(
    SettingSlot<int> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const ColorArgbCodec());
}

/// A nullable [Color] setting, stored as its ARGB value.
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class ColorNullableSetting extends StoredNullableSetting<Color, int> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [ColorSetting.new].
  ColorNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    Color? defaultValue,
    SettingValidator<Color?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the ARGB value.
  ColorNullableSetting.inSlot(
    SettingSlot<int> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const ColorArgbCodec());
}
