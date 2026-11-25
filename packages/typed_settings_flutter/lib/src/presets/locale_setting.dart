import 'dart:ui';

import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings_flutter/src/codec/locale_subtags_codec.dart';

/// A [Locale] setting (the language the user picked for the app), stored
/// as its language, script and region; see [LocaleSubtagsCodec].
///
/// A variant or an extension is rejected and is not written.
base class LocaleSetting extends StoredSetting<Locale, String> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  LocaleSetting({
    required SettingsStorage storage,
    required String key,
    required Locale defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<Locale>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the language, script and region.
  LocaleSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const LocaleSubtagsCodec());
}

/// A nullable [Locale] setting, stored as its language, script and region.
/// `null` is the usual "follow the device" choice.
///
/// A variant or an extension is rejected and is not written.
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class LocaleNullableSetting extends StoredNullableSetting<Locale, String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [LocaleSetting.new].
  LocaleNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    Locale? defaultValue,
    SettingValidator<Locale?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the language, script and region.
  LocaleNullableSetting.inSlot(
    SettingSlot<String> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const LocaleSubtagsCodec());
}
