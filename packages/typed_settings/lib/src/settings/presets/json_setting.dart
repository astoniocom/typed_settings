import 'dart:convert';

import 'package:typed_settings/src/codec/json_object_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A value of a model class stored as a JSON object string, converted
/// with `fromJson` and `toJson` (see [JsonObjectCodec]): what
/// json_serializable and freezed generate.
///
/// ```dart
/// final filter = JsonSetting(
///   storage: preferences,
///   key: 'filter',
///   defaultValue: const Filter(),
///   fromJson: Filter.fromJson,
///   toJson: (filter) => filter.toJson(),
/// );
/// ```
///
/// Two values are equal when `toJson` encodes them to the same JSON, so
/// a class without `==` of its own is compared by content as well. The
/// class should be immutable: the setting hands out the instance it
/// caches, and a change made to it in place is neither stored nor
/// noticed. Assign a new value instead (`filter.value = filter.value
/// .copyWith(...)`).
///
/// The value is one stored string: every change encodes and writes all of
/// it. That suits a settings object; data that grows with use belongs in
/// a database table, not a setting.
base class JsonSetting<T> extends StoredSetting<T, String> {
  /// Creates the setting stored under [key] of [storage]; values are
  /// converted with [fromJson] and [toJson]. [legacyKeys] are the keys it
  /// was stored under before, most recent first (see [KeyedSettingSlot]).
  JsonSetting({
    required SettingsStorage storage,
    required String key,
    required T defaultValue,
    required T Function(Map<String, Object?> json) fromJson,
    required Map<String, Object?> Function(T value) toJson,
    List<String> legacyKeys = const [],
    SettingValidator<T>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         fromJson: fromJson,
         toJson: toJson,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON object; see [JsonSetting.new] for the other
  /// parameters.
  JsonSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    required T Function(Map<String, Object?> json) fromJson,
    required Map<String, Object?> Function(T value) toJson,
    super.validator,
  }) : super(
         slot: slot,
         codec: JsonObjectCodec(fromJson: fromJson, toJson: toJson),
         equality: _sameJson(toJson),
       );
}

/// A nullable value of a model class stored as a JSON object string; see
/// [JsonSetting].
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class JsonNullableSetting<T extends Object> extends StoredNullableSetting<T, String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [JsonSetting.new].
  JsonNullableSetting({
    required SettingsStorage storage,
    required String key,
    required T Function(Map<String, Object?> json) fromJson,
    required Map<String, Object?> Function(T value) toJson,
    List<String> legacyKeys = const [],
    T? defaultValue,
    SettingValidator<T?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         fromJson: fromJson,
         toJson: toJson,
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON object; see [JsonSetting.new] for the other
  /// parameters.
  JsonNullableSetting.inSlot(
    SettingSlot<String> slot, {
    required T Function(Map<String, Object?> json) fromJson,
    required Map<String, Object?> Function(T value) toJson,
    super.defaultValue,
    super.validator,
  }) : super(
         slot: slot,
         codec: JsonObjectCodec(fromJson: fromJson, toJson: toJson),
         equality: _sameJson(toJson),
       );
}

/// Whether two values encode to the same JSON through [toJson].
bool Function(T a, T b) _sameJson<T>(Map<String, Object?> Function(T value) toJson) =>
    (a, b) => identical(a, b) || json.encode(toJson(a)) == json.encode(toJson(b));
