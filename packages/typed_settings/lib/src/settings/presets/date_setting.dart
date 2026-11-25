import 'package:typed_settings/src/codec/calendar_date_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A calendar date (a birthday, a due date), stored as `yyyy-MM-dd`.
///
/// Its values are what [CalendarDateCodec] gives back: local midnight of
/// the date, from the moment they are assigned (see `StoredSetting`). The
/// time of day of an assigned [DateTime] is dropped, and the date stays
/// the same when the device's time zone changes. For a moment in time use
/// `DateTimeSetting`.
base class DateSetting extends StoredSetting<DateTime, String> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  DateSetting({
    required SettingsStorage storage,
    required String key,
    required DateTime defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<DateTime>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the date.
  DateSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const CalendarDateCodec());
}

/// A nullable calendar date, stored as `yyyy-MM-dd`; see [DateSetting].
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class DateNullableSetting extends StoredNullableSetting<DateTime, String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [DateSetting.new].
  DateNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    DateTime? defaultValue,
    SettingValidator<DateTime?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the date.
  DateNullableSetting.inSlot(
    SettingSlot<String> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const CalendarDateCodec());
}
