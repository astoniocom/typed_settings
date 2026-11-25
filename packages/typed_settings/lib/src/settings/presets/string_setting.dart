import 'package:typed_settings/src/codec/setting_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A `String` setting.
base class StringSetting extends StoredSetting<String, String> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  StringSetting({
    required SettingsStorage storage,
    required String key,
    required String defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<String>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  StringSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const IdentityCodec());
}

/// A nullable `String` setting.
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class StringNullableSetting extends StoredNullableSetting<String, String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [StringSetting.new].
  StringNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    String? defaultValue,
    SettingValidator<String?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  StringNullableSetting.inSlot(
    SettingSlot<String> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const IdentityCodec());
}
