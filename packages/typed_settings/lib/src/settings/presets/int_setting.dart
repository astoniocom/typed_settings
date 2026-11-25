import 'package:typed_settings/src/codec/setting_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// An `int` setting.
base class IntSetting extends StoredSetting<int, int> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  IntSetting({
    required SettingsStorage storage,
    required String key,
    required int defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<int>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  IntSetting.inSlot(
    SettingSlot<int> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const IdentityCodec());
}

/// A nullable `int` setting.
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class IntNullableSetting extends StoredNullableSetting<int, int> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [IntSetting.new].
  IntNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    int? defaultValue,
    SettingValidator<int?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  IntNullableSetting.inSlot(
    SettingSlot<int> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const IdentityCodec());
}
