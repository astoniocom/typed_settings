import 'package:typed_settings/src/codec/setting_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A `double` setting.
base class DoubleSetting extends StoredSetting<double, double> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  DoubleSetting({
    required SettingsStorage storage,
    required String key,
    required double defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<double>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofDouble(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  DoubleSetting.inSlot(
    SettingSlot<double> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const IdentityCodec());
}

/// A nullable `double` setting.
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class DoubleNullableSetting extends StoredNullableSetting<double, double> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [DoubleSetting.new].
  DoubleNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    double? defaultValue,
    SettingValidator<double?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofDouble(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  DoubleNullableSetting.inSlot(
    SettingSlot<double> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const IdentityCodec());
}
