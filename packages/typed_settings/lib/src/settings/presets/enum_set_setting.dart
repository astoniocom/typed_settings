import 'package:typed_settings/src/codec/enum_name_codec.dart';
import 'package:typed_settings/src/settings/presets/set_setting.dart';

/// A set of enum constants stored as a JSON array of their names: enabled
/// notification channels, selected categories. See [EnumNameCodec] for
/// renamed constants.
///
/// A name that is neither a current nor a legacy one makes the whole
/// stored set unusable, so the setting falls back to its default and
/// reports it, and keeps the stored set until another value replaces it
/// (a constant a newer release added reads again once it is back).
base class EnumSetSetting<T extends Enum> extends SetSetting<T> {
  /// Creates the setting stored under [key] of [storage]. Every constant
  /// of [defaultValue] must be one of [values] (an [ArgumentError] reports
  /// it otherwise), [legacyNames] maps former constant names to current
  /// constants; see [SetSetting.new] for the other parameters.
  EnumSetSetting({
    required super.storage,
    required super.key,
    required super.defaultValue,
    required this.values,
    super.legacyKeys,
    Map<String, T> legacyNames = const {},
    super.validator,
  }) : super(
         fromJson: _nameReader(_holdingDefault(values, defaultValue), legacyNames),
         toJson: _name,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON array of names; see [EnumSetSetting.new].
  EnumSetSetting.inSlot(
    super.slot, {
    required super.defaultValue,
    required this.values,
    Map<String, T> legacyNames = const {},
    super.validator,
  }) : super.inSlot(
         fromJson: _nameReader(_holdingDefault(values, defaultValue), legacyNames),
         toJson: _name,
       );

  /// The constants the set may hold, in declaration order.
  final List<T> values;
}

/// A nullable set of enum constants stored as a JSON array of their
/// names; see [EnumSetSetting].
base class EnumSetNullableSetting<T extends Enum> extends SetNullableSetting<T> {
  /// Creates the setting stored under [key] of [storage]; every constant
  /// of a non-null [defaultValue] must be one of [values]. `null` is
  /// stored as an explicit null, distinct from nothing stored, which
  /// yields [defaultValue]. See [EnumSetSetting.new].
  EnumSetNullableSetting({
    required super.storage,
    required super.key,
    required this.values,
    super.legacyKeys,
    Map<String, T> legacyNames = const {},
    super.defaultValue,
    super.validator,
  }) : super(
         fromJson: _nameReader(_holdingDefault(values, defaultValue), legacyNames),
         toJson: _name,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON array of names; see [EnumSetNullableSetting.new].
  EnumSetNullableSetting.inSlot(
    super.slot, {
    required this.values,
    Map<String, T> legacyNames = const {},
    super.defaultValue,
    super.validator,
  }) : super.inSlot(
         fromJson: _nameReader(_holdingDefault(values, defaultValue), legacyNames),
         toJson: _name,
       );

  /// The constants the set may hold, in declaration order.
  final List<T> values;
}

/// Reads an element: a name of one of [values], current or legacy.
T Function(Object? json) _nameReader<T extends Enum>(List<T> values, Map<String, T> legacyNames) {
  final codec = EnumNameCodec(values, legacyNames: legacyNames);
  return (json) => json is String
      ? codec.decode(json)
      : throw FormatException('Expected the name of an enum constant, got ${json.runtimeType}', '$json');
}

Object? _name(Enum value) => value.name;

/// [values], once every constant of [defaultValue] is found to be one of
/// them. Called from the initializer list, so that a rejected default
/// fails before `StoredSetting` registers with the slot.
List<T> _holdingDefault<T extends Enum>(List<T> values, Set<T>? defaultValue) {
  final strays = defaultValue?.where((value) => !values.contains(value)) ?? const [];
  if (strays.isEmpty) return values;
  throw ArgumentError.value(defaultValue, 'defaultValue', 'holds ${strays.join(', ')}, which values does not');
}
