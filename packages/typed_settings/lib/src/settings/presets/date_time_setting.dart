import 'package:typed_settings/src/codec/date_time_millis_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A moment in time, stored as milliseconds since the epoch.
///
/// Its values are what [DateTimeMillisCodec] gives back: local time, with
/// millisecond precision, from the moment they are assigned (see
/// `StoredSetting`). A `DateTime.utc` value therefore reads as the same
/// moment in local time; compare moments with [DateTime.isAtSameMomentAs].
///
/// It is a moment, not a wall-clock time: once the device's time zone
/// changes, the same stored value reads as another time of day. A time of
/// day meant in local time wherever the device is (an alarm at 09:00) is
/// not one; store its hour and minute instead, for example as an
/// `IntSetting` of minutes since midnight.
base class DateTimeSetting extends StoredSetting<DateTime, int> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  DateTimeSetting({
    required SettingsStorage storage,
    required String key,
    required DateTime defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<DateTime>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the milliseconds.
  DateTimeSetting.inSlot(
    SettingSlot<int> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const DateTimeMillisCodec());
}

/// A nullable [DateTime] setting, stored as milliseconds since the epoch;
/// values are in local time, see [DateTimeSetting].
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class DateTimeNullableSetting extends StoredNullableSetting<DateTime, int> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [DateTimeSetting.new].
  DateTimeNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    DateTime? defaultValue,
    SettingValidator<DateTime?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the milliseconds.
  DateTimeNullableSetting.inSlot(
    SettingSlot<int> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const DateTimeMillisCodec());
}
