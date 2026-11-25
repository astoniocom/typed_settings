import 'package:typed_settings/src/codec/duration_millis_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A [Duration] setting, stored as whole milliseconds.
base class DurationSetting extends StoredSetting<Duration, int> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  DurationSetting({
    required SettingsStorage storage,
    required String key,
    required Duration defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<Duration>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the milliseconds.
  DurationSetting.inSlot(
    SettingSlot<int> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const DurationMillisCodec());
}

/// A nullable [Duration] setting, stored as whole milliseconds.
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class DurationNullableSetting extends StoredNullableSetting<Duration, int> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [DurationSetting.new].
  DurationNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    Duration? defaultValue,
    SettingValidator<Duration?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the milliseconds.
  DurationNullableSetting.inSlot(
    SettingSlot<int> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const DurationMillisCodec());
}
