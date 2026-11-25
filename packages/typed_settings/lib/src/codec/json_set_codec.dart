import 'dart:convert';

import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores a set as a JSON array string, converting each element with
/// [fromJson] / [toJson]. Elements are written in the set's iteration
/// order.
///
/// [decode] throws a [FormatException] when the string is not a JSON array;
/// element conversion errors propagate as thrown by [fromJson]. Either way
/// the whole set is rejected, as by `JsonListCodec`. Elements that the
/// array holds twice are read once.
final class JsonSetCodec<T> implements SettingCodec<Set<T>, String> {
  /// Creates a codec converting elements with [fromJson] and [toJson].
  const JsonSetCodec({
    required this.fromJson,
    required this.toJson,
  });

  /// Converts one decoded JSON value into an element. Throw a
  /// [FormatException] for values that are not acceptable.
  final T Function(Object? json) fromJson;

  /// Converts an element into a JSON-encodable value.
  final Object? Function(T element) toJson;

  @override
  Set<T> decode(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! List) {
      throw FormatException('Expected a JSON array, got ${decoded.runtimeType}', raw);
    }
    return decoded.map(fromJson).toSet();
  }

  @override
  String encode(Set<T> value) => json.encode([for (final element in value) toJson(element)]);
}
