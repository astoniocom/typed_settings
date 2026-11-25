import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores an enum constant by its `name`.
///
/// Renaming a constant invalidates stored values unless the old name is
/// listed in `legacyNames`; [decode] throws a [FormatException] for a name
/// that is neither current nor legacy. Legacy names are read only; values
/// are always written under their current name.
final class EnumNameCodec<T extends Enum> implements SettingCodec<T, String> {
  /// [values] are the constants to recognise (typically `MyEnum.values`);
  /// [legacyNames] maps former names to the constants they now denote.
  EnumNameCodec(
    List<T> values, {
    Map<String, T> legacyNames = const {},
  }) : _byName = {
         ...legacyNames,
         for (final value in values) value.name: value,
       };

  final Map<String, T> _byName;

  @override
  T decode(String raw) {
    final value = _byName[raw];
    if (value == null) {
      throw FormatException('Unknown enum value; expected one of ${_byName.keys.join(', ')}', raw);
    }
    return value;
  }

  @override
  String encode(T value) => value.name;
}
