import 'package:typed_settings/src/codec/setting_codec.dart';

/// Stores a [DateTime] as milliseconds since the Unix epoch.
///
/// Only the moment is stored, to the millisecond: decoded values are in
/// the local time zone, as [DateTime.fromMillisecondsSinceEpoch] produces
/// them, without microseconds. [decode] throws a [FormatException] for a
/// value outside the range a [DateTime] can hold.
final class DateTimeMillisCodec implements SettingCodec<DateTime, int> {
  /// Creates the codec; stateless, so prefer the `const` form.
  const DateTimeMillisCodec();

  /// Largest magnitude [DateTime.fromMillisecondsSinceEpoch] accepts
  /// (100,000,000 days from the epoch).
  static const int _maxMillisSinceEpoch = 8640000000000000;

  @override
  DateTime decode(int raw) {
    if (raw.abs() > _maxMillisSinceEpoch) {
      throw FormatException('Milliseconds since epoch out of DateTime range', '$raw');
    }
    return DateTime.fromMillisecondsSinceEpoch(raw);
  }

  @override
  int encode(DateTime value) => value.millisecondsSinceEpoch;
}
