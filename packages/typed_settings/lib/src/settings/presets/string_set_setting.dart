import 'package:typed_settings/src/codec/json_element_converters.dart';
import 'package:typed_settings/src/settings/presets/set_setting.dart';

/// A set of strings stored as a JSON array.
///
/// An element that is not a string makes the whole stored set unusable,
/// so the setting falls back to its default and reports it.
base class StringSetSetting extends SetSetting<String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [SetSetting.new].
  StringSetSetting({
    required super.storage,
    required super.key,
    required super.defaultValue,
    super.legacyKeys,
    super.validator,
  }) : super(
         fromJson: stringFromJson,
         toJson: jsonIdentity,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  StringSetSetting.inSlot(
    super.slot, {
    required super.defaultValue,
    super.validator,
  }) : super.inSlot(
         fromJson: stringFromJson,
         toJson: jsonIdentity,
       );
}

/// A nullable set of strings stored as a JSON array; elements are read as
/// in [StringSetSetting].
base class StringSetNullableSetting extends SetNullableSetting<String> {
  /// Creates the setting stored under [key] of [storage]. `null` is stored
  /// as an explicit null, distinct from nothing stored, which yields
  /// [defaultValue].
  StringSetNullableSetting({
    required super.storage,
    required super.key,
    super.legacyKeys,
    super.defaultValue,
    super.validator,
  }) : super(
         fromJson: stringFromJson,
         toJson: jsonIdentity,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  StringSetNullableSetting.inSlot(
    super.slot, {
    super.defaultValue,
    super.validator,
  }) : super.inSlot(
         fromJson: stringFromJson,
         toJson: jsonIdentity,
       );
}
