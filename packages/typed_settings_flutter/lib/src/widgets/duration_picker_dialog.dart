import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';

/// A dialog that picks a [Duration] in hours, minutes and seconds.
///
/// Pops with the picked duration in a [DialogResult], with `DialogResult(null)` when
/// cleared and with `null` when dismissed.
class DurationPickerDialog extends StatefulWidget {
  /// Creates a dialog titled [title] that opens on [initial].
  const DurationPickerDialog({
    required this.title,
    this.initial,
    this.allowClear = false,
    super.key,
  });

  /// The title of the dialog.
  final String title;

  /// The duration the dialog opens on; zero when null.
  final Duration? initial;

  /// Whether the dialog offers to clear a non-null [initial] to `null`.
  final bool allowClear;

  @override
  State<DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<DurationPickerDialog> {
  late int _hours;
  late int _minutes;
  late int _seconds;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? Duration.zero;
    _hours = initial.inHours;
    _minutes = initial.inMinutes.remainder(60);
    _seconds = initial.inSeconds.remainder(60);
  }

  Duration get _current => Duration(hours: _hours, minutes: _minutes, seconds: _seconds);

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
            _formatDuration(_current),
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 24),
          // Spinners
          _SpinnerRow(
            label: localizations.timePickerHourLabel,
            value: _hours,
            min: 0,
            onChanged: (v) => setState(() => _hours = v),
          ),
          const Divider(height: 1),
          _SpinnerRow(
            label: localizations.timePickerMinuteLabel,
            value: _minutes,
            min: 0,
            max: 59,
            onChanged: (v) => setState(() => _minutes = v),
          ),
          const Divider(height: 1),
          _SpinnerRow(
            label: TypedSettingsLocalizations.of(context).secondsLabel,
            value: _seconds,
            min: 0,
            max: 59,
            onChanged: (v) => setState(() => _seconds = v),
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
          onPressed: () => Navigator.pop(context, DialogResult(_current)),
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}

class _SpinnerRow extends StatelessWidget {
  const _SpinnerRow({
    required this.label,
    required this.value,
    required this.min,
    required this.onChanged,
    this.max,
  });

  final String label;
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: value > min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toString().padLeft(2, '0'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: value < (max ?? value + 1) ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}
