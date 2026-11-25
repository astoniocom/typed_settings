import 'dart:convert';

import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores a list as a JSON array string, converting each element with
/// [fromJson] / [toJson].
///
/// [decode] throws a [FormatException] when the string is not a JSON array;
/// element conversion errors propagate as thrown by [fromJson]. Either way
/// the whole list is rejected: a partially read list would silently drop
/// data, whereas a rejected one is reported and replaced by the default.
final class JsonListCodec<T> implements SettingCodec<List<T>, String> {
  /// Creates a codec converting elements with [fromJson] and [toJson].
  const JsonListCodec({
    required this.fromJson,
    required this.toJson,
  });

  /// Converts one decoded JSON value (`int`, `double`, `String`, `bool`,
  /// `null`, `List` or `Map`) into an element. Throw a [FormatException]
  /// for values that are not acceptable.
  final T Function(Object? json) fromJson;

  /// Converts an element into a JSON-encodable value.
  final Object? Function(T element) toJson;

  @override
  List<T> decode(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! List) {
      throw FormatException('Expected a JSON array, got ${decoded.runtimeType}', raw);
    }
    return decoded.map(fromJson).toList(growable: false);
  }

  @override
  String encode(List<T> value) => json.encode(value.map(toJson).toList(growable: false));
}
