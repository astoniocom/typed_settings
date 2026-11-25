import 'package:typed_settings/src/codec/enum_name_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// An enum constant setting, stored by name; see [EnumNameCodec] for
/// renamed constants.
base class EnumSetting<T extends Enum> extends StoredSetting<T, String> {
  /// Creates the setting stored under [key] of [storage]. [defaultValue]
  /// must be one of [values] (an [ArgumentError] reports it otherwise),
  /// [legacyNames] maps former constant names to current constants, and
  /// [legacyKeys] are the keys it was stored under before, most recent
  /// first (see [KeyedSettingSlot]).
  EnumSetting({
    required SettingsStorage storage,
    required String key,
    required T defaultValue,
    required List<T> values,
    List<String> legacyKeys = const [],
    Map<String, T> legacyNames = const {},
    SettingValidator<T>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         values: values,
         legacyNames: legacyNames,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the name; see [EnumSetting.new] for the other parameters.
  EnumSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    required this.values,
    Map<String, T> legacyNames = const {},
    super.validator,
  }) : super(
         slot: slot,
         codec: EnumNameCodec(_holdingDefault(values, defaultValue), legacyNames: legacyNames),
       );

  /// The constants the setting may hold, in declaration order.
  final List<T> values;
}

/// A nullable enum constant setting, stored by name.
base class EnumNullableSetting<T extends Enum> extends StoredNullableSetting<T, String> {
  /// Creates the setting stored under [key] of [storage]; a non-null
  /// [defaultValue] must be one of [values]. See [EnumSetting.new].
  EnumNullableSetting({
    required SettingsStorage storage,
    required String key,
    required List<T> values,
    List<String> legacyKeys = const [],
    Map<String, T> legacyNames = const {},
    T? defaultValue,
    SettingValidator<T?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         values: values,
         legacyNames: legacyNames,
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the name; see [EnumNullableSetting.new] for the other
  /// parameters.
  EnumNullableSetting.inSlot(
    SettingSlot<String> slot, {
    required this.values,
    Map<String, T> legacyNames = const {},
    super.defaultValue,
    super.validator,
  }) : super(
         slot: slot,
         codec: EnumNameCodec(_holdingDefault(values, defaultValue), legacyNames: legacyNames),
       );

  /// The constants the setting may hold, in declaration order.
  final List<T> values;
}

/// [values], once [defaultValue] is found to be absent or one of them.
/// Called from the initializer list, so that a rejected default fails
/// before `StoredSetting` registers with the slot.
List<T> _holdingDefault<T extends Enum>(List<T> values, T? defaultValue) {
  if (defaultValue == null || values.contains(defaultValue)) return values;
  throw ArgumentError.value(defaultValue, 'defaultValue', 'must be one of values');
}
