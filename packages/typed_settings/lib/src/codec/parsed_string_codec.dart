import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores a value as the string [format] gives, read back with [parse]:
/// for a type that parses its own string form (`BigInt.parse`, a version,
/// an identifier from another package).
///
/// [parse] throws a [FormatException] for a string it cannot read, as the
/// `parse` methods of the core library do. [format] gives a string that
/// [parse] reads back as an equal value; a value it cannot represent
/// makes the assignment fail with what [parse] throws.
///
/// The registry compares codecs by type (see `SettingsRegistry`): two
/// codecs of one value type with different functions pass its check, so
/// give every setting over one key the same codec.
final class ParsedStringCodec<T> implements SettingCodec<T, String> {
  /// Creates a codec reading values with [parse] and writing them with
  /// [format].
  const ParsedStringCodec({
    required this.parse,
    required this.format,
  });

  /// Reads a stored string.
  final T Function(String raw) parse;

  /// Gives the string to store for a value.
  final String Function(T value) format;

  @override
  T decode(String raw) => parse(raw);

  @override
  String encode(T value) => format(value);
}
