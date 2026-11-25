import 'package:typed_settings/src/codec/json_element_converters.dart';
import 'package:typed_settings/src/settings/presets/list_setting.dart';

/// A list of integers stored as a JSON array.
///
/// Integral doubles (`2.0`, as some JSON producers emit) are read as
/// integers; anything else that is not an integer makes the whole stored
/// list unusable, so the setting falls back to its default and reports it.
base class IntListSetting extends ListSetting<int> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [ListSetting.new].
  IntListSetting({
    required super.storage,
    required super.key,
    required super.defaultValue,
    super.legacyKeys,
    super.validator,
  }) : super(
         fromJson: intFromJson,
         toJson: jsonIdentity,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  IntListSetting.inSlot(
    super.slot, {
    required super.defaultValue,
    super.validator,
  }) : super.inSlot(
         fromJson: intFromJson,
         toJson: jsonIdentity,
       );
}

/// A nullable list of integers stored as a JSON array; elements are read
/// as in [IntListSetting].
base class IntListNullableSetting extends ListNullableSetting<int> {
  /// Creates the setting stored under [key] of [storage]. `null` is stored
  /// as an explicit null, distinct from nothing stored, which yields
  /// [defaultValue].
  IntListNullableSetting({
    required super.storage,
    required super.key,
    super.legacyKeys,
    super.defaultValue,
    super.validator,
  }) : super(
         fromJson: intFromJson,
         toJson: jsonIdentity,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  IntListNullableSetting.inSlot(
    super.slot, {
    super.defaultValue,
    super.validator,
  }) : super.inSlot(
         fromJson: intFromJson,
         toJson: jsonIdentity,
       );
}
