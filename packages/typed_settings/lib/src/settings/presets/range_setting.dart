import 'package:typed_settings/src/codec/date_time_millis_codec.dart';
import 'package:typed_settings/src/codec/duration_millis_codec.dart';
import 'package:typed_settings/src/codec/json_range_codec.dart';
import 'package:typed_settings/src/foundation/value_range.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';
import 'package:typed_settings/src/validation/validation_errors.dart';

/// A [ValueRange] stored as one JSON array of two elements.
///
/// The ends are converted with `fromJson` and `toJson`. When `compare` is
/// given, the end must not be before the start: this is part of the
/// invariant, ahead of `validator`. Assigning a range out of order throws a
/// `SettingValidationException` with a [ForbiddenValueValidationError]
/// (and `validate` returns that error), and a stored range out of order
/// falls back to the default. `compare` returns a negative number, zero or
/// a positive number as the start is before, at or after the end, as
/// [Comparable.compareTo] does.
///
/// [ofInt], [ofDouble], [ofDuration] and [ofDateTime] compare the ends.
/// Leave `compare` out for a range whose end may be earlier.
///
/// `null` is not a range. A range that is absent as a whole is a
/// [RangeNullableSetting].
base class RangeSetting<T extends Object> extends StoredSetting<ValueRange<T>, String> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  RangeSetting({
    required SettingsStorage storage,
    required String key,
    required ValueRange<T> defaultValue,
    required T Function(Object? json) fromJson,
    required Object? Function(T value) toJson,
    int Function(T start, T end)? compare,
    List<String> legacyKeys = const [],
    SettingValidator<ValueRange<T>>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         fromJson: fromJson,
         toJson: toJson,
         compare: compare,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON array; see [RangeSetting.new].
  RangeSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    required T Function(Object? json) fromJson,
    required Object? Function(T value) toJson,
    int Function(T start, T end)? compare,
    SettingValidator<ValueRange<T>>? validator,
  }) : super(
         slot: slot,
         codec: JsonRangeCodec(fromJson: fromJson, toJson: toJson),
         validator: _withOrder(compare, validator),
       );

  /// An `int` range. The end is at or after the start.
  static RangeSetting<int> ofInt({
    required SettingsStorage storage,
    required String key,
    required ValueRange<int> defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<ValueRange<int>>? validator,
  }) => RangeSetting<int>(
    storage: storage,
    key: key,
    defaultValue: defaultValue,
    fromJson: _intFromJson,
    toJson: _intToJson,
    compare: _compare<num>,
    legacyKeys: legacyKeys,
    validator: validator,
  );

  /// A `double` range. A JSON integer is read as a double. The end is at
  /// or after the start.
  static RangeSetting<double> ofDouble({
    required SettingsStorage storage,
    required String key,
    required ValueRange<double> defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<ValueRange<double>>? validator,
  }) => RangeSetting<double>(
    storage: storage,
    key: key,
    defaultValue: defaultValue,
    fromJson: _doubleFromJson,
    toJson: _doubleToJson,
    compare: _compare<num>,
    legacyKeys: legacyKeys,
    validator: validator,
  );

  /// A [Duration] range, each end stored as whole milliseconds. The end
  /// is at or after the start.
  static RangeSetting<Duration> ofDuration({
    required SettingsStorage storage,
    required String key,
    required ValueRange<Duration> defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<ValueRange<Duration>>? validator,
  }) => RangeSetting<Duration>(
    storage: storage,
    key: key,
    defaultValue: defaultValue,
    fromJson: _durationFromJson,
    toJson: _durationToJson,
    compare: _compare<Duration>,
    legacyKeys: legacyKeys,
    validator: validator,
  );

  /// A [DateTime] range. Each end is a moment stored as milliseconds
  /// since the epoch and read back in local time, the way one moment is
  /// stored. The end is at or after the start.
  static RangeSetting<DateTime> ofDateTime({
    required SettingsStorage storage,
    required String key,
    required ValueRange<DateTime> defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<ValueRange<DateTime>>? validator,
  }) => RangeSetting<DateTime>(
    storage: storage,
    key: key,
    defaultValue: defaultValue,
    fromJson: _dateTimeFromJson,
    toJson: _dateTimeToJson,
    compare: _compare<DateTime>,
    legacyKeys: legacyKeys,
    validator: validator,
  );
}

/// A nullable [ValueRange], stored as one JSON array of two elements.
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue]. It means the whole range is absent and
/// passes the order check. See [RangeSetting] for the ends and their order.
base class RangeNullableSetting<T extends Object> extends StoredNullableSetting<ValueRange<T>, String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [RangeSetting.new].
  RangeNullableSetting({
    required SettingsStorage storage,
    required String key,
    required T Function(Object? json) fromJson,
    required Object? Function(T value) toJson,
    int Function(T start, T end)? compare,
    List<String> legacyKeys = const [],
    ValueRange<T>? defaultValue,
    SettingValidator<ValueRange<T>?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         fromJson: fromJson,
         toJson: toJson,
         compare: compare,
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON array; see [RangeSetting.new].
  RangeNullableSetting.inSlot(
    SettingSlot<String> slot, {
    required T Function(Object? json) fromJson,
    required Object? Function(T value) toJson,
    int Function(T start, T end)? compare,
    super.defaultValue,
    SettingValidator<ValueRange<T>?>? validator,
  }) : super(
         slot: slot,
         codec: JsonRangeCodec(fromJson: fromJson, toJson: toJson),
         validator: _withOrder(compare, validator),
       );

  /// A nullable `int` range. The end is at or after the start.
  static RangeNullableSetting<int> ofInt({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    ValueRange<int>? defaultValue,
    SettingValidator<ValueRange<int>?>? validator,
  }) => RangeNullableSetting<int>(
    storage: storage,
    key: key,
    legacyKeys: legacyKeys,
    defaultValue: defaultValue,
    fromJson: _intFromJson,
    toJson: _intToJson,
    compare: _compare<num>,
    validator: validator,
  );

  /// A nullable `double` range. A JSON integer is read as a double. The
  /// end is at or after the start.
  static RangeNullableSetting<double> ofDouble({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    ValueRange<double>? defaultValue,
    SettingValidator<ValueRange<double>?>? validator,
  }) => RangeNullableSetting<double>(
    storage: storage,
    key: key,
    legacyKeys: legacyKeys,
    defaultValue: defaultValue,
    fromJson: _doubleFromJson,
    toJson: _doubleToJson,
    compare: _compare<num>,
    validator: validator,
  );

  /// A nullable [Duration] range, each end stored as whole milliseconds.
  /// The end is at or after the start.
  static RangeNullableSetting<Duration> ofDuration({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    ValueRange<Duration>? defaultValue,
    SettingValidator<ValueRange<Duration>?>? validator,
  }) => RangeNullableSetting<Duration>(
    storage: storage,
    key: key,
    legacyKeys: legacyKeys,
    defaultValue: defaultValue,
    fromJson: _durationFromJson,
    toJson: _durationToJson,
    compare: _compare<Duration>,
    validator: validator,
  );

  /// A nullable [DateTime] range; see [RangeSetting.ofDateTime]. The end
  /// is at or after the start.
  static RangeNullableSetting<DateTime> ofDateTime({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    ValueRange<DateTime>? defaultValue,
    SettingValidator<ValueRange<DateTime>?>? validator,
  }) => RangeNullableSetting<DateTime>(
    storage: storage,
    key: key,
    legacyKeys: legacyKeys,
    defaultValue: defaultValue,
    fromJson: _dateTimeFromJson,
    toJson: _dateTimeToJson,
    compare: _compare<DateTime>,
    validator: validator,
  );
}

/// [validator] preceded by the order of the ends under [compare]; `null`
/// passes the order check.
SettingValidator<R>? _withOrder<T extends Object, R extends ValueRange<T>?>(
  int Function(T start, T end)? compare,
  SettingValidator<R>? validator,
) {
  if (compare == null) return validator;
  final order = SettingValidator<R>((range) {
    if (range == null || compare(range.start, range.end) <= 0) return null;
    return ForbiddenValueValidationError(range, debugDescription: 'the end is before the start');
  });
  return validator == null ? order : SettingValidator.all([order, validator]);
}

int _compare<T extends Comparable<T>>(T start, T end) => start.compareTo(end);

int _intFromJson(Object? json) {
  if (json is int) return json;
  throw FormatException('Expected an integer', json);
}

Object? _intToJson(int value) => value;

double _doubleFromJson(Object? json) {
  if (json is int) return json.toDouble();
  if (json is double) return json;
  throw FormatException('Expected a number', json);
}

Object? _doubleToJson(double value) => value;

Duration _durationFromJson(Object? json) {
  if (json is! int) throw FormatException('Expected whole milliseconds', json);
  return const DurationMillisCodec().decode(json);
}

Object? _durationToJson(Duration value) => const DurationMillisCodec().encode(value);

DateTime _dateTimeFromJson(Object? json) {
  if (json is! int) throw FormatException('Expected milliseconds since the epoch', json);
  return const DateTimeMillisCodec().decode(json);
}

Object? _dateTimeToJson(DateTime value) => const DateTimeMillisCodec().encode(value);
