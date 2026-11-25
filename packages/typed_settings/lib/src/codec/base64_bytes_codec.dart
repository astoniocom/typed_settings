import 'dart:convert';
import 'dart:typed_data';

import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores bytes as a Base64 string (RFC 4648, with padding). [decode]
/// throws a [FormatException] for a string that is not Base64; it accepts
/// the URL-safe alphabet too.
final class Base64BytesCodec implements SettingCodec<Uint8List, String> {
  /// Creates the codec; stateless, so prefer the `const` form.
  const Base64BytesCodec();

  @override
  Uint8List decode(String raw) => base64.decode(raw);

  @override
  String encode(Uint8List value) => base64.encode(value);
}
