import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';
import 'package:typed_settings_flutter/src/widgets/number_format.dart';

/// A dialog that picks a `double` between [min] and [max] with a slider.
///
/// Pops with the picked value in a [DialogResult], with `DialogResult(null)` when cleared
/// and with `null` when dismissed.
class DoublePickerDialog extends StatefulWidget {
  /// Creates a dialog titled [title] that opens on [initial].
  const DoublePickerDialog({
    required this.initial,
    required this.min,
    required this.max,
    required this.title,
    required this.fractionDigits,
    this.allowClear = false,
    this.divisions,
    super.key,
  });

  /// The value the dialog opens on. A value outside [min] and [max] is what
  /// OK returns until the slider moves; the slider shows the nearest bound
  /// meanwhile, because it cannot represent a value outside its range.
  /// Null opens on an empty display and a slider at [min].
  final double? initial;

  /// The lowest value the slider offers.
  final double min;

  /// The highest value the slider offers.
  final double max;

  /// The number of discrete steps of the slider; continuous when null.
  final int? divisions;

  /// The number of digits after the decimal point the dialog shows.
  final int fractionDigits;

  /// The title of the dialog.
  final String title;

  /// Whether the dialog offers to clear a non-null [initial] to `null`.
  final bool allowClear;

  @override
  State<DoublePickerDialog> createState() => _DoublePickerDialogState();
}

class _DoublePickerDialogState extends State<DoublePickerDialog> {
  late final double? _original;
  late double _slider;
  var _moved = false;

  @override
  void initState() {
    super.initState();
    _original = widget.initial;
    final initial = widget.initial;
    _slider = initial == null ? widget.min : initial.clamp(widget.min, widget.max);
  }

  /// The value OK stores: the stored value until the slider moves, then
  /// the slider's value.
  double? get _result => _moved ? _slider : _original;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final messages = TypedSettingsLocalizations.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          CloseButton(onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Large display of the current value
          Text(
            switch (_result) {
              final result? => formatFixed(context, result, widget.fractionDigits),
              null => '',
            },
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          // Slider with min/max labels
          Row(
            children: [
              Text(
                formatFixed(context, widget.min, widget.fractionDigits),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              Expanded(
                child: Slider(
                  value: _slider,
                  min: widget.min,
                  max: widget.max,
                  divisions: widget.divisions,
                  label: formatFixed(context, _slider, widget.fractionDigits),
                  onChanged: (value) => setState(() {
                    _slider = value;
                    _moved = true;
                  }),
                ),
              ),
              Text(
                formatFixed(context, widget.max, widget.fractionDigits),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (widget.allowClear && widget.initial != null)
          TextButton(
            onPressed: () => Navigator.pop(context, const DialogResult(null)),
            child: Text(messages.clearValueLabel),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, DialogResult(_result)),
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }
}
