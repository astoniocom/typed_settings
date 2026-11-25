import 'dart:convert';

import 'package:typed_settings/src/codec/setting_codec.dart';
import 'package:typed_settings/src/foundation/value_range.dart';

/// Stores a [ValueRange] as a JSON array of exactly two elements, the
/// start and then the end.
///
/// [fromJson] and [toJson] convert one end. [decode] throws a
/// [FormatException] when the string is not JSON, is not an array, or
/// does not hold two elements. What [fromJson] throws for an element
/// propagates, and the whole range is rejected.
///
/// The codec does not order the ends: a range whose end is before its
/// start is stored as given. An order the ends must keep is the
/// setting's invariant (see `RangeSetting`), so that assigning a range
/// out of order is a validation error, not a failure to encode.
final class JsonRangeCodec<T extends Object> implements SettingCodec<ValueRange<T>, String> {
  /// Creates a codec converting each end with [fromJson] and [toJson].
  const JsonRangeCodec({required this.fromJson, required this.toJson});

  /// Converts one decoded JSON value into an end. Throw a
  /// [FormatException] for a value that is not acceptable.
  final T Function(Object? json) fromJson;

  /// Converts an end into a JSON-encodable value.
  final Object? Function(T value) toJson;

  @override
  ValueRange<T> decode(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! List || decoded.length != 2) {
      throw FormatException('Expected a JSON array of two elements', raw);
    }
    return ValueRange<T>(start: fromJson(decoded[0]), end: fromJson(decoded[1]));
  }

  @override
  String encode(ValueRange<T> value) => json.encode([toJson(value.start), toJson(value.end)]);
}
