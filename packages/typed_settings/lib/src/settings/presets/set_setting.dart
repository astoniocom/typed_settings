import 'package:collection/collection.dart';
import 'package:typed_settings/src/codec/json_set_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A set stored as a JSON array string; elements are converted with
/// `fromJson` / `toJson` (see [JsonSetCodec]). Two sets are equal when
/// they hold the same elements, in any order.
///
/// The set is immutable: [value] returns an unmodifiable set, and an
/// assigned set is copied before it is cached, so later changes to the
/// caller's set have no effect. Assign a new set to change the setting.
/// Elements are expected to be immutable, as elements of a set should be
/// anyway: one changed in place would change its hash code.
///
/// The set is one stored string: every change encodes, copies and writes
/// all of it. That suits a handful of elements (enabled categories,
/// selected filters); a collection that grows with use belongs in a
/// database table, not a setting.
base class SetSetting<T> extends StoredSetting<Set<T>, String> {
  /// Creates the setting stored under [key] of [storage]; elements are
  /// converted with [fromJson] and [toJson]. [legacyKeys] are the keys it
  /// was stored under before, most recent first (see [KeyedSettingSlot]).
  SetSetting({
    required SettingsStorage storage,
    required String key,
    required Set<T> defaultValue,
    required T Function(Object? json) fromJson,
    required Object? Function(T element) toJson,
    List<String> legacyKeys = const [],
    SettingValidator<Set<T>>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         fromJson: fromJson,
         toJson: toJson,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON array; see [SetSetting.new] for the other
  /// parameters.
  SetSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    required T Function(Object? json) fromJson,
    required Object? Function(T element) toJson,
    super.validator,
  }) : super(
         slot: slot,
         codec: JsonSetCodec(fromJson: fromJson, toJson: toJson),
         equality: SetEquality<T>().equals,
         snapshot: Set<T>.unmodifiable,
       );
}

/// A nullable set stored as a JSON array string; see [SetSetting].
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class SetNullableSetting<T> extends StoredNullableSetting<Set<T>, String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [SetSetting.new].
  SetNullableSetting({
    required SettingsStorage storage,
    required String key,
    required T Function(Object? json) fromJson,
    required Object? Function(T element) toJson,
    List<String> legacyKeys = const [],
    Set<T>? defaultValue,
    SettingValidator<Set<T>?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         fromJson: fromJson,
         toJson: toJson,
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON array; see [SetSetting.new] for the other
  /// parameters.
  SetNullableSetting.inSlot(
    SettingSlot<String> slot, {
    required T Function(Object? json) fromJson,
    required Object? Function(T element) toJson,
    super.defaultValue,
    super.validator,
  }) : super(
         slot: slot,
         codec: JsonSetCodec(fromJson: fromJson, toJson: toJson),
         equality: SetEquality<T>().equals,
         snapshot: Set<T>.unmodifiable,
       );
}
