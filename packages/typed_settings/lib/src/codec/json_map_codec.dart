import 'dart:convert';

import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores a JSON-like map as a JSON object string.
///
/// [decode] throws a [FormatException] when the string is not a JSON
/// object; [encode] throws when the map holds a value that is not
/// JSON-representable.
final class JsonMapCodec implements SettingCodec<Map<String, Object?>, String> {
  /// Creates the codec; stateless, so prefer the `const` form.
  const JsonMapCodec();

  @override
  Map<String, Object?> decode(String raw) {
    final decoded = json.decode(raw);
    if (decoded is! Map<String, Object?>) {
      throw FormatException('Expected a JSON object, got ${decoded.runtimeType}', raw);
    }
    return decoded;
  }

  @override
  String encode(Map<String, Object?> value) => json.encode(value);
}
