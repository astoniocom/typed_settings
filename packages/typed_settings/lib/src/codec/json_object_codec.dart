import 'dart:convert';

import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores a value as a JSON object string, converted with [fromJson] and
/// [toJson].
///
/// They have the shape of the `fromJson` constructor and the `toJson`
/// method that json_serializable and freezed generate, so a model class is
/// stored with `JsonObjectCodec(fromJson: Profile.fromJson, toJson: (p) =>
/// p.toJson())`.
///
/// [decode] throws a [FormatException] when the string is not a JSON
/// object; what [fromJson] throws for an object it cannot read propagates.
/// Generated code throws a `TypeError` for a field of another type, which
/// the setting reports as a bug and replaces by its default; a [fromJson]
/// written by hand throws a [FormatException] instead (see
/// [SettingCodec]).
final class JsonObjectCodec<T> implements SettingCodec<T, String> {
  /// Creates a codec converting values with [fromJson] and [toJson].
  const JsonObjectCodec({
    required this.fromJson,
    required this.toJson,
  });

  /// Converts a decoded JSON object into a value.
  final T Function(Map<String, Object?> json) fromJson;

  /// Converts a value into a JSON object: a map whose values are
  /// JSON-encodable, or objects with a `toJson` method of their own.
  final Map<String, Object?> Function(T value) toJson;

  @override
  T decode(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('Expected a JSON object, got ${decoded.runtimeType}', raw);
    }
    return fromJson(decoded);
  }

  @override
  String encode(T value) => json.encode(toJson(value));
}
