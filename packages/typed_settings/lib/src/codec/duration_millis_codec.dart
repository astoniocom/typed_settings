import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores a [Duration] as a whole number of milliseconds; finer precision is
/// dropped.
final class DurationMillisCodec implements SettingCodec<Duration, int> {
  /// Creates the codec; stateless, so prefer the `const` form.
  const DurationMillisCodec();

  @override
  Duration decode(int raw) => Duration(milliseconds: raw);

  @override
  int encode(Duration value) => value.inMilliseconds;
}
