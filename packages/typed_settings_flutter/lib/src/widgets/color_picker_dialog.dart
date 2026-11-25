import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/color_preview.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';

/// A dialog that picks a color from [presets] or a hex field.
///
/// [initial] is offered and marked even when it is not one of [presets].
/// A swatch or the field chooses the color; OK stores it. Pops with that
/// color in a [DialogResult], with `DialogResult(null)` when cleared and
/// with `null` when dismissed.
class ColorPickerDialog extends StatefulWidget {
  /// Creates a dialog that offers [presets] and marks [initial].
  const ColorPickerDialog({
    required this.presets,
    this.initial,
    this.allowNull = false,
    this.title,
    super.key,
  });

  /// The color the dialog opens on.
  final Color? initial;

  /// Whether the dialog offers to clear a non-null [initial] to `null`.
  final bool allowNull;

  /// The title of the dialog.
  final String? title;

  /// The colors the dialog offers, besides [initial] when it is not among them.
  final List<Color> presets;

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late final TextEditingController _hex = TextEditingController(
    text: switch (widget.initial) {
      final color? => colorHex(color),
      null => '',
    },
  );
  Color? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  List<Color> get _swatches {
    final colors = <Color>[...widget.presets];
    void include(Color? color) {
      if (color != null && !colors.contains(color)) colors.insert(0, color);
    }

    include(widget.initial);
    include(_selected);
    return colors;
  }

  void _choose(Color color) {
    setState(() {
      _selected = color;
      _hex.text = colorHex(color);
    });
  }

  void _onHex(String text) {
    setState(() => _selected = _parse(text));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final messages = TypedSettingsLocalizations.of(context);
    final parsed = _parse(_hex.text);
    final invalid = _hex.text.trim().isNotEmpty && parsed == null;
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: widget.title != null ? Text(widget.title!) : const SizedBox.shrink()),
          CloseButton(onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 330,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in _swatches)
                    Semantics(
                      button: true,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _choose(color),
                        child: ColorPreview(color: color, isSelected: _selected == color),
                      ),
                    ),
                  if (widget.allowNull && widget.initial != null)
                    SizedBox.square(
                      dimension: ColorPreview.size,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        tooltip: messages.clearColorLabel,
                        onPressed: () => Navigator.pop(context, const DialogResult<Color?>(null)),
                        icon: const Icon(Icons.format_color_reset),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _hex,
                decoration: InputDecoration(
                  labelText: messages.colorHexLabel,
                  errorText: invalid ? messages.invalidColor : null,
                ),
                onChanged: _onHex,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: parsed == null ? null : () => Navigator.pop(context, DialogResult(parsed)),
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }
}

/// [text] as `#RRGGBB` or `#AARRGGBB`, or null when it is not one.
Color? _parse(String text) {
  final hex = text.trim().replaceFirst('#', '');
  if (hex.length != 6 && hex.length != 8) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return Color(hex.length == 6 ? 0xFF000000 | value : value);
}
