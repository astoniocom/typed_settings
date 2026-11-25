/// How a backend that can only store strings records one scalar.
///
/// The first character is the type and the rest is the payload. A string's
/// payload is the string itself, so any string can be stored, including one
/// that looks like another type or like the explicit-null tag. An int is
/// therefore not a string, and [encodeStoredNull] is not a string a caller
/// stored.
///
/// Tags: `n` explicit null, `s` a string, `b0`/`b1` a bool, `i` then the
/// decimal of an int, `d` then the double as its `toString` gives it.
/// Anything else was not written by these functions.
///
/// There is no reader for an older untagged value, nor for the former
/// sentinel `\u{E000}typed_settings:null`. A stored string equal to that
/// sentinel could not be told from an explicit null, so guessing would keep
/// the collision. A backend that already holds the old form needs a
/// migration the application writes; until then such a value is reported
/// and reads as absent.
library;

const _nullTag = 'n';
const _stringTag = 's';
const _boolTag = 'b';
const _intTag = 'i';
const _doubleTag = 'd';

/// The stored form of an explicit null.
String encodeStoredNull() => _nullTag;

/// The stored form of [value]. Any content is preserved, including one that
/// looks like another tag.
String encodeStoredString(String value) => '$_stringTag$value';

/// The stored form of [value].
String encodeStoredBool(bool value) => '$_boolTag${value ? '1' : '0'}';

/// The stored form of [value], decimal, sign included.
String encodeStoredInt(int value) => '$_intTag$value';

/// The stored form of [value], using [double.toString] for the payload so
/// that infinities and `NaN` round-trip through [double.tryParse].
String encodeStoredDouble(double value) => '$_doubleTag$value';

/// Reads [raw] back. [EncodedGarbage] when it is not a form the encode
/// functions produce.
EncodedScalar decodeStoredScalar(String raw) {
  if (raw.isEmpty) return EncodedGarbage(raw);
  final tag = raw[0];
  final payload = raw.substring(1);
  switch (tag) {
    case _nullTag:
      return payload.isEmpty ? const EncodedNull() : EncodedGarbage(raw);
    case _stringTag:
      return EncodedString(payload);
    case _boolTag:
      return switch (payload) {
        '0' => const EncodedBool(false),
        '1' => const EncodedBool(true),
        _ => EncodedGarbage(raw),
      };
    case _intTag:
      final value = int.tryParse(payload);
      return value == null ? EncodedGarbage(raw) : EncodedInt(value);
    case _doubleTag:
      final value = double.tryParse(payload);
      return value == null ? EncodedGarbage(raw) : EncodedDouble(value);
    default:
      return EncodedGarbage(raw);
  }
}

/// One scalar [decodeStoredScalar] read back.
sealed class EncodedScalar {
  const EncodedScalar();

  /// What a typed getter reports when this is not the type it asked for:
  /// the value itself, or the stored text when it is not a scalar at all.
  Object? get reportable;
}

/// An explicit null, distinct from an absent key.
final class EncodedNull extends EncodedScalar {
  /// Creates the null scalar.
  const EncodedNull();

  @override
  Object? get reportable => null;
}

/// A bool.
final class EncodedBool extends EncodedScalar {
  /// Creates a bool scalar of [value].
  const EncodedBool(this.value);

  /// The bool.
  final bool value;

  @override
  Object? get reportable => value;
}

/// An int.
final class EncodedInt extends EncodedScalar {
  /// Creates an int scalar of [value].
  const EncodedInt(this.value);

  /// The int.
  final int value;

  @override
  Object? get reportable => value;
}

/// A double.
final class EncodedDouble extends EncodedScalar {
  /// Creates a double scalar of [value].
  const EncodedDouble(this.value);

  /// The double.
  final double value;

  @override
  Object? get reportable => value;
}

/// A string, which may be empty and may look like any other tag.
final class EncodedString extends EncodedScalar {
  /// Creates a string scalar of [value].
  const EncodedString(this.value);

  /// The string.
  final String value;

  @override
  Object? get reportable => value;
}

/// Stored text these functions did not write.
final class EncodedGarbage extends EncodedScalar {
  /// Creates a garbage scalar for the stored [raw] text.
  const EncodedGarbage(this.raw);

  /// The stored text.
  final String raw;

  @override
  Object? get reportable => raw;
}
