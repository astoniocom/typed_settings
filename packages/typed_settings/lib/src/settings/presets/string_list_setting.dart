import 'package:typed_settings/src/codec/json_element_converters.dart';
import 'package:typed_settings/src/settings/presets/list_setting.dart';

/// A list of strings stored as a JSON array.
///
/// An element that is not a string makes the whole stored list unusable,
/// so the setting falls back to its default and reports it.
base class StringListSetting extends ListSetting<String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [ListSetting.new].
  StringListSetting({
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
  StringListSetting.inSlot(
    super.slot, {
    required super.defaultValue,
    super.validator,
  }) : super.inSlot(
         fromJson: stringFromJson,
         toJson: jsonIdentity,
       );
}

/// A nullable list of strings stored as a JSON array; elements are read as
/// in [StringListSetting].
base class StringListNullableSetting extends ListNullableSetting<String> {
  /// Creates the setting stored under [key] of [storage]. `null` is stored
  /// as an explicit null, distinct from nothing stored, which yields
  /// [defaultValue].
  StringListNullableSetting({
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
  StringListNullableSetting.inSlot(
    super.slot, {
    super.defaultValue,
    super.validator,
  }) : super.inSlot(
         fromJson: stringFromJson,
         toJson: jsonIdentity,
       );
}
