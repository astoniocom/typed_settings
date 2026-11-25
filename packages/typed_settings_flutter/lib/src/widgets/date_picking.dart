import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';

/// Shows the date picker used by [pickDateTime].
///
/// [onClear] is non-null when the picker should offer to clear the value.
/// A custom picker calls it and then ends without a date.
typedef PickDate = Future<DateTime?> Function(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  VoidCallback? onClear,
});

/// Shows the time picker used by [pickDateTime] and [pickTimeOfDay].
///
/// [onClear] is non-null when the picker should offer to clear the value.
/// A custom picker calls it and then ends without a time.
typedef PickTime = Future<TimeOfDay?> Function(
  BuildContext context, {
  required TimeOfDay initialTime,
  VoidCallback? onClear,
});

/// The bounds of a date picker that opens on [current].
///
/// A bound not given is ten years from today. Any bound that [current]
/// lies beyond, whether it was given or filled in here, moves to
/// [current]. The picker therefore opens on the stored value, and
/// confirming that date does not replace it with the bound.
({DateTime first, DateTime initial, DateTime last}) datePickerBounds(
  DateTime current, {
  DateTime? firstDate,
  DateTime? lastDate,
}) {
  const span = Duration(days: 365 * 10);
  final now = DateTime.now();
  var first = firstDate ?? now.subtract(span);
  var last = lastDate ?? now.add(span);
  if (current.isBefore(first)) first = current;
  if (current.isAfter(last)) last = current;
  return (first: first, initial: current, last: last);
}

/// A `builder` for `showDatePicker` or `showTimePicker` that adds a clear
/// button under the picker. The button calls [onClear] and closes the
/// picker, so the picker returns null.
TransitionBuilder pickerWithClearButton(VoidCallback onClear) {
  return (dialogContext, child) => SafeArea(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        TextButton(
          onPressed: () {
            onClear();
            Navigator.pop(dialogContext);
          },
          child: Text(TypedSettingsLocalizations.of(dialogContext).clearValueLabel),
        ),
      ],
    ),
  );
}

/// Picks a date, then a time of day when [pickTime].
///
/// Returns null when the date picker is dismissed. Returns
/// `DialogResult(null)` when its clear button is used. Otherwise returns the
/// picked value. Cancelling the time picker keeps the time of [current], or
/// of the moment the picker opened when [current] is null, on the confirmed
/// date. Confirming a time stores that hour and minute; the seconds are zero.
///
/// [pickDate] and [pickTimeOfDay] replace the Material pickers. A custom
/// picker calls its `onClear` callback and then ends without a value when
/// the user clears.
Future<DialogResult<DateTime?>?> pickDateTime(
  BuildContext context, {
  required DateTime? current,
  DateTime? firstDate,
  DateTime? lastDate,
  bool pickTime = true,
  bool allowClear = false,
  PickDate? pickDate,
  PickTime? pickTimeOfDay,
}) async {
  final openedAt = current ?? DateTime.now();
  final bounds = datePickerBounds(openedAt, firstDate: firstDate, lastDate: lastDate);
  var cleared = false;
  void clear() => cleared = true;

  final date = await (pickDate ?? _materialDate)(
    context,
    initialDate: bounds.initial,
    firstDate: bounds.first,
    lastDate: bounds.last,
    onClear: allowClear ? clear : null,
  );
  if (cleared) return const DialogResult(null);
  if (date == null || !context.mounted) return null;
  if (!pickTime) return DialogResult(date);

  final time = await (pickTimeOfDay ?? _materialTime)(
    context,
    initialTime: TimeOfDay.fromDateTime(openedAt),
    onClear: allowClear ? clear : null,
  );
  if (!context.mounted) return null;
  if (cleared) return const DialogResult(null);
  if (time == null) return DialogResult(dateKeepingTime(date, openedAt));
  return DialogResult(DateTime(date.year, date.month, date.day, time.hour, time.minute));
}

/// Picks a time of day.
///
/// Returns null when the picker is dismissed and `DialogResult(null)` when
/// its clear button is used. [pick] replaces the Material picker.
Future<DialogResult<TimeOfDay?>?> pickTimeOfDay(
  BuildContext context, {
  required TimeOfDay? current,
  bool allowClear = false,
  PickTime? pick,
}) async {
  var cleared = false;
  final time = await (pick ?? _materialTime)(
    context,
    initialTime: current ?? TimeOfDay.now(),
    onClear: allowClear ? () => cleared = true : null,
  );
  if (cleared) return const DialogResult(null);
  if (time == null || !context.mounted) return null;
  return DialogResult(time);
}

Future<DateTime?> _materialDate(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  VoidCallback? onClear,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: onClear == null ? null : pickerWithClearButton(onClear),
  );
}

Future<TimeOfDay?> _materialTime(
  BuildContext context, {
  required TimeOfDay initialTime,
  VoidCallback? onClear,
}) {
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    builder: onClear == null ? null : pickerWithClearButton(onClear),
  );
}

/// [date]'s calendar day with the time of day from [time].
DateTime dateKeepingTime(DateTime date, DateTime time) => DateTime(
  date.year,
  date.month,
  date.day,
  time.hour,
  time.minute,
  time.second,
  time.millisecond,
  time.microsecond,
);

/// [value] as a date, and a time when [withTime], the way the Material
/// pickers of [context] show them: the time follows the device's 24-hour
/// setting.
String formatDateTime(BuildContext context, DateTime value, {required bool withTime}) {
  final date = MaterialLocalizations.of(context).formatCompactDate(value);
  if (!withTime) return date;
  return '$date ${formatTimeOfDay(context, TimeOfDay.fromDateTime(value))}';
}

/// [time] the way the Material time picker of [context] shows it: in the
/// device's 24-hour setting.
String formatTimeOfDay(BuildContext context, TimeOfDay time) => MaterialLocalizations.of(
  context,
).formatTimeOfDay(time, alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context));
