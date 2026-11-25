import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:typed_settings/typed_settings_extend.dart';

/// Stores a [TimeOfDay] as the minutes since midnight, 0 to 1439.
///
/// [decode] throws a [FormatException] for a number outside that range.
/// [encode] throws one for a time outside the day, and the assignment
/// fails with that exception before anything is stored.
final class TimeOfDayMinutesCodec implements SettingCodec<TimeOfDay, int> {
  /// Creates the codec; stateless, so prefer the `const` form.
  const TimeOfDayMinutesCodec();

  static const _minutesPerDay = TimeOfDay.hoursPerDay * TimeOfDay.minutesPerHour;

  @override
  TimeOfDay decode(int raw) {
    if (raw < 0 || raw >= _minutesPerDay) {
      throw FormatException('Expected minutes since midnight, 0 to ${_minutesPerDay - 1}', '$raw');
    }
    return TimeOfDay(hour: raw ~/ TimeOfDay.minutesPerHour, minute: raw % TimeOfDay.minutesPerHour);
  }

  @override
  int encode(TimeOfDay value) {
    final hour = value.hour;
    final minute = value.minute;
    if (hour < 0 || hour >= TimeOfDay.hoursPerDay || minute < 0 || minute >= TimeOfDay.minutesPerHour) {
      throw FormatException(
        'Expected an hour from 0 to ${TimeOfDay.hoursPerDay - 1} and a minute from 0 to ${TimeOfDay.minutesPerHour - 1}',
        value,
      );
    }
    return hour * TimeOfDay.minutesPerHour + minute;
  }
}
