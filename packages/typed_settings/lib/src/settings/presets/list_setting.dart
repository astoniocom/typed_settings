import 'package:collection/collection.dart';
import 'package:typed_settings/src/codec/json_list_codec.dart';
import 'package:typed_settings/src/settings/presets/freeze.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A list stored as a JSON array string; elements are converted with
/// `fromJson` / `toJson`. Values are compared element-wise, elements that
/// are collections by content.
///
/// The list is immutable: [value] returns an unmodifiable list, and an
/// assigned list is copied before it is cached, so later changes to the
/// caller's list have no effect. Assign a new list to change the setting.
///
/// Elements are what `fromJson` makes of the stored JSON, never the
/// caller's objects (see `StoredSetting` on values as stored). Immutable
/// element types (`int`, `String`, value classes) need nothing more; for
/// mutable ones such as maps pass `snapshotElement` (for JSON-like maps,
/// [freezeJsonMap]) so that the setting's value cannot be changed in
/// place.
///
/// The list is one stored string: every change encodes, copies and writes
/// all of it, and it is held in memory from the moment its storage loads.
/// That suits a handful of elements; a collection that grows with use, or
/// is edited element by element, belongs in a database table, not a
/// setting.
base class ListSetting<T> extends StoredSetting<List<T>, String> {
  /// Creates the setting stored under [key] of [storage]; elements are
  /// converted with [fromJson] and [toJson] and optionally copied with
  /// [snapshotElement]. [legacyKeys] are the keys it was stored under
  /// before, most recent first (see [KeyedSettingSlot]).
  ListSetting({
    required SettingsStorage storage,
    required String key,
    required List<T> defaultValue,
    required T Function(Object? json) fromJson,
    required Object? Function(T element) toJson,
    List<String> legacyKeys = const [],
    T Function(T element)? snapshotElement,
    SettingValidator<List<T>>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         fromJson: fromJson,
         toJson: toJson,
         snapshotElement: snapshotElement,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON array; see [ListSetting.new] for the other
  /// parameters.
  ListSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    required T Function(Object? json) fromJson,
    required Object? Function(T element) toJson,
    T Function(T element)? snapshotElement,
    super.validator,
  }) : super(
         slot: slot,
         codec: JsonListCodec(fromJson: fromJson, toJson: toJson),
         equality: const DeepCollectionEquality().equals,
         snapshot: (list) => freezeList(list, snapshotElement),
       );
}

/// A nullable list stored as a JSON array string; elements are converted
/// with `fromJson` / `toJson`. Values are compared element-wise, elements
/// that are collections by content.
///
/// The list is immutable: [value] returns an unmodifiable list, and an
/// assigned list is copied before it is cached, so later changes to the
/// caller's list have no effect. Assign a new list to change the setting.
/// See [ListSetting] on `snapshotElement` for mutable element types.
base class ListNullableSetting<T> extends StoredNullableSetting<List<T>, String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [ListSetting.new].
  ListNullableSetting({
    required SettingsStorage storage,
    required String key,
    required T Function(Object? json) fromJson,
    required Object? Function(T element) toJson,
    List<String> legacyKeys = const [],
    T Function(T element)? snapshotElement,
    List<T>? defaultValue,
    SettingValidator<List<T>?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         fromJson: fromJson,
         toJson: toJson,
         snapshotElement: snapshotElement,
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the JSON array; see [ListSetting.new] for the other
  /// parameters.
  ListNullableSetting.inSlot(
    SettingSlot<String> slot, {
    required T Function(Object? json) fromJson,
    required Object? Function(T element) toJson,
    T Function(T element)? snapshotElement,
    super.defaultValue,
    super.validator,
  }) : super(
         slot: slot,
         codec: JsonListCodec(fromJson: fromJson, toJson: toJson),
         equality: const DeepCollectionEquality().equals,
         snapshot: (list) => freezeList(list, snapshotElement),
       );
}
