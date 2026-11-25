import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores a [Uri] as its string form. [decode] throws a [FormatException]
/// for strings that do not parse.
final class UriStringCodec implements SettingCodec<Uri, String> {
  /// Creates the codec; stateless, so prefer the `const` form.
  const UriStringCodec();

  @override
  Uri decode(String raw) => Uri.parse(raw);

  @override
  String encode(Uri value) => value.toString();
}
