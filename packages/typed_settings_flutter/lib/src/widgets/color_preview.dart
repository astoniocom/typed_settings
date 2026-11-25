import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';

/// `#AARRGGBB` for [color].
String colorHex(Color color) => '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// A circle filled with [color], ringed and checked when [isSelected].
///
/// A screen reader hears the color as its [colorHex], and an empty circle
/// as [TypedSettingsLocalizations.notSetLabel]: Material has no color names.
class ColorPreview extends StatelessWidget {
  /// Creates a preview of [color].
  const ColorPreview({
    required this.color,
    this.isSelected = false,
    super.key,
  });

  /// The diameter of the circle.
  static const size = 40.0;

  /// The fill of the circle; empty when null.
  final Color? color;

  /// Whether the circle is ringed in the primary color and checked.
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    return Semantics(
      label: color == null ? TypedSettingsLocalizations.of(context).notSetLabel : colorHex(color),
      selected: isSelected,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 18,
                color: ThemeData.estimateBrightnessForColor(color ?? Colors.transparent) == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : null,
      ),
    );
  }
}
