import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores the calendar date of a [DateTime] as `yyyy-MM-dd`, without a
/// time of day or a time zone: a birthday, a due date.
///
/// [encode] takes the date as the value shows it: a UTC value gives its
/// UTC date, a local one its local date. It throws an [ArgumentError] for
/// a year outside 0 to 9999. [decode] gives local midnight of the date
/// (`DateTime(year, month, day)`), so the date stays the same wherever the
/// device is; it throws a [FormatException] for a string that is not such
/// a date, `2024-02-30` included.
final class CalendarDateCodec implements SettingCodec<DateTime, String> {
  /// Creates the codec; stateless, so prefer the `const` form.
  const CalendarDateCodec();

  static final _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  @override
  DateTime decode(String raw) {
    final match = _date.firstMatch(raw);
    if (match == null) throw FormatException('Expected a date as yyyy-MM-dd', raw);
    final [year, month, day] = [for (var group = 1; group <= 3; group++) int.parse(match[group]!)];
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException('Not a day of the calendar', raw);
    }
    return date;
  }

  @override
  String encode(DateTime value) {
    if (value.year < 0 || value.year > 9999) {
      throw ArgumentError.value(value, 'value', 'has a year outside 0 to 9999, which yyyy-MM-dd cannot hold');
    }
    String digits(int number, int width) => '$number'.padLeft(width, '0');
    return '${digits(value.year, 4)}-${digits(value.month, 2)}-${digits(value.day, 2)}';
  }
}
