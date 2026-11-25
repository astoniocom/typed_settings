import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';

/// A dialog that edits an `int` in a number field with step buttons.
///
/// Pops with the entered value in a [DialogResult], with `DialogResult(null)` when
/// cleared and with `null` when dismissed. OK is disabled while the text is
/// not an integer within [min] and [max], including the value the dialog
/// opens on. The error text comes from [TypedSettingsLocalizations].
class IntPickerDialog extends StatefulWidget {
  /// Creates a dialog titled [title] that opens on [initial].
  const IntPickerDialog({
    required this.title,
    this.allowClear = false,
    this.initial,
    this.min,
    this.max,
    super.key,
  });

  /// The title of the dialog.
  final String title;

  /// The value the dialog opens on; an empty field when null.
  final int? initial;

  /// Whether the dialog offers to clear a non-null [initial] to `null`.
  final bool allowClear;

  /// The lowest value the dialog accepts; unbounded when null.
  final int? min;

  /// The highest value the dialog accepts; unbounded when null.
  final int? max;

  @override
  State<IntPickerDialog> createState() => _IntPickerDialogState();
}

class _IntPickerDialogState extends State<IntPickerDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? get _parsed => int.tryParse(_controller.text.trim());

  /// The error for [text], or null when it is empty or an integer within
  /// [IntPickerDialog.min] and [IntPickerDialog.max].
  String? _messageFor(String text, TypedSettingsLocalizations messages) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    if (value == null) return messages.invalidInteger;
    final min = widget.min;
    if (min != null && value < min) return messages.rangeValue(min: min);
    final max = widget.max;
    if (max != null && value > max) return messages.rangeValue(max: max);
    return null;
  }

  void _increment() {
    final current = _parsed ?? 0;
    final next = current + 1;
    if (widget.max != null && next > widget.max!) return;
    setState(() => _controller.text = '$next');
  }

  void _decrement() {
    final current = _parsed ?? 0;
    final prev = current - 1;
    if (widget.min != null && prev < widget.min!) return;
    setState(() => _controller.text = '$prev');
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final messages = TypedSettingsLocalizations.of(context);
    final error = _messageFor(_controller.text, messages);
    final canSubmit = error == null && _parsed != null;
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
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed: _decrement,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
                    ],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      errorText: error,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (canSubmit) Navigator.pop(context, DialogResult(_parsed));
                    },
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _increment,
              ),
            ],
          ),
          // Range hint
          if (widget.min != null || widget.max != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                [
                  if (widget.min != null) messages.minimumHint(widget.min!),
                  if (widget.max != null) messages.maximumHint(widget.max!),
                ].join('  •  '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
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
          onPressed: canSubmit ? () => Navigator.pop(context, DialogResult(_parsed)) : null,
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }
}
