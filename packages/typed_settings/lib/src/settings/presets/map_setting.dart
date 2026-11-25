import 'package:collection/collection.dart';
import 'package:typed_settings/src/codec/json_map_codec.dart';
import 'package:typed_settings/src/settings/presets/freeze.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A JSON-like map stored as a JSON object string, compared structurally.
///
/// The value is immutable: [value] returns an unmodifiable deep copy, and
/// an assigned map is deep-copied before it is cached or stored, so later
/// changes to the caller's map have no effect. Assign a new map to change
/// the setting.
///
/// The map is one stored string: every change encodes, copies and writes
/// all of it, and it is held in memory from the moment its storage loads.
/// That suits a handful of entries; a collection that grows with use, or
/// is edited entry by entry, belongs in a database table, not a setting.
base class MapSetting extends StoredSetting<Map<String, Object?>, String> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  MapSetting({
    required SettingsStorage storage,
    required String key,
    required Map<String, Object?> defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<Map<String, Object?>>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON object.
  MapSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(
         slot: slot,
         codec: const JsonMapCodec(),
         equality: const DeepCollectionEquality().equals,
         snapshot: freezeJsonMap,
       );
}

/// A nullable JSON-like map stored as a JSON object string, compared
/// structurally.
///
/// The value is immutable: [value] returns an unmodifiable deep copy, and
/// an assigned map is deep-copied before it is cached or stored, so later
/// changes to the caller's map have no effect. Assign a new map to change
/// the setting.
base class MapNullableSetting extends StoredNullableSetting<Map<String, Object?>, String> {
  /// Creates the setting stored under [key] of [storage]. `null` is stored
  /// as an explicit null, distinct from nothing stored, which yields
  /// [defaultValue]. See [MapSetting.new].
  MapNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    Map<String, Object?>? defaultValue,
    SettingValidator<Map<String, Object?>?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON object.
  MapNullableSetting.inSlot(
    SettingSlot<String> slot, {
    super.defaultValue,
    super.validator,
  }) : super(
         slot: slot,
         codec: const JsonMapCodec(),
         equality: const DeepCollectionEquality().equals,
         snapshot: freezeJsonMap,
       );
}
