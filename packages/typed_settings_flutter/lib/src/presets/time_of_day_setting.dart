import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings_flutter/src/codec/time_of_day_minutes_codec.dart';

/// A [TimeOfDay] setting (a reminder at 09:00, the start of quiet hours),
/// stored as the minutes since midnight; see [TimeOfDayMinutesCodec].
///
/// It is a time on the wall clock, not a moment: it reads as the same
/// hour and minute in every time zone. For a moment in time use
/// `DateTimeSetting`.
base class TimeOfDaySetting extends StoredSetting<TimeOfDay, int> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  TimeOfDaySetting({
    required SettingsStorage storage,
    required String key,
    required TimeOfDay defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<TimeOfDay>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the minutes since midnight.
  TimeOfDaySetting.inSlot(
    SettingSlot<int> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const TimeOfDayMinutesCodec());
}

/// A nullable [TimeOfDay] setting, stored as the minutes since midnight;
/// see [TimeOfDaySetting].
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class TimeOfDayNullableSetting extends StoredNullableSetting<TimeOfDay, int> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [TimeOfDaySetting.new].
  TimeOfDayNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    TimeOfDay? defaultValue,
    SettingValidator<TimeOfDay?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the minutes since midnight.
  TimeOfDayNullableSetting.inSlot(
    SettingSlot<int> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const TimeOfDayMinutesCodec());
}

/// A [ValueRange] of [TimeOfDay], stored as one JSON array of the minutes
/// since midnight of each end.
///
/// The end may be earlier than the start. That is a range which crosses
/// midnight, such as 22:00 to 07:00, and it is stored as given. `null` is
/// not a range; a range that is absent as a whole is a
/// [TimeOfDayRangeNullableSetting].
base class TimeOfDayRangeSetting extends StoredSetting<ValueRange<TimeOfDay>, String> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  TimeOfDayRangeSetting({
    required SettingsStorage storage,
    required String key,
    required ValueRange<TimeOfDay> defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<ValueRange<TimeOfDay>>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON array.
  TimeOfDayRangeSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: _timeOfDayRangeCodec);
}

/// A nullable [ValueRange] of [TimeOfDay]; see [TimeOfDayRangeSetting].
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue]. It means the whole range is absent.
base class TimeOfDayRangeNullableSetting extends StoredNullableSetting<ValueRange<TimeOfDay>, String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [TimeOfDayRangeSetting.new].
  TimeOfDayRangeNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    ValueRange<TimeOfDay>? defaultValue,
    SettingValidator<ValueRange<TimeOfDay>?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON array.
  TimeOfDayRangeNullableSetting.inSlot(
    SettingSlot<String> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: _timeOfDayRangeCodec);
}

const _timeOfDayRangeCodec = JsonRangeCodec<TimeOfDay>(fromJson: _timeFromJson, toJson: _timeToJson);

TimeOfDay _timeFromJson(Object? json) {
  if (json is! int) throw FormatException('Expected minutes since midnight', json);
  return const TimeOfDayMinutesCodec().decode(json);
}

Object? _timeToJson(TimeOfDay value) => const TimeOfDayMinutesCodec().encode(value);
