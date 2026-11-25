import 'package:typed_settings/src/codec/setting_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A `bool` setting.
///
/// ```dart
/// final enabled = BoolSetting(storage: storage, key: 'enabled', defaultValue: true);
/// ```
base class BoolSetting extends StoredSetting<bool, bool> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  BoolSetting({
    required SettingsStorage storage,
    required String key,
    required bool defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<bool>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofBool(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  BoolSetting.inSlot(
    SettingSlot<bool> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const IdentityCodec());
}

/// A nullable `bool` setting.
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class BoolNullableSetting extends StoredNullableSetting<bool, bool> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [BoolSetting.new].
  BoolNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    bool? defaultValue,
    SettingValidator<bool?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofBool(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  BoolNullableSetting.inSlot(
    SettingSlot<bool> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const IdentityCodec());
}
