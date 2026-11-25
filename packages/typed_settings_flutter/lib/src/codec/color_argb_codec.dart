import 'dart:ui';

import 'package:typed_settings/typed_settings_extend.dart';

/// Stores a [Color] as its 32-bit ARGB value in sRGB.
///
/// A color in another color space (Display P3) is converted to sRGB first,
/// with components outside the sRGB gamut clamped, so that it reads back
/// as an sRGB color close to it rather than as its components
/// reinterpreted; 8 bits per channel is the precision kept.
final class ColorArgbCodec implements SettingCodec<Color, int> {
  /// Creates the codec; stateless, so prefer the `const` form.
  const ColorArgbCodec();

  @override
  Color decode(int raw) => Color(raw);

  @override
  int encode(Color value) {
    // Through extendedSRGB and an explicit clamp: a conversion straight to
    // sRGB only clamps the components without converting them (Flutter
    // 3.47), and on the web toARGB32 wraps components outside [0, 1].
    final srgb = value.withValues(colorSpace: ColorSpace.extendedSRGB);
    return Color.from(
      alpha: srgb.a.clamp(0.0, 1.0),
      red: srgb.r.clamp(0.0, 1.0),
      green: srgb.g.clamp(0.0, 1.0),
      blue: srgb.b.clamp(0.0, 1.0),
    ).toARGB32();
  }
}
