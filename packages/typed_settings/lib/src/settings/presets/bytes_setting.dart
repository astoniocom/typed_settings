import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:typed_settings/src/codec/base64_bytes_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// Bytes (a key, a salt, a token), stored as a Base64 string. Two values
/// are equal when they hold the same bytes.
///
/// The bytes are immutable: [value] returns an unmodifiable view, and
/// assigned bytes are copied before they are cached, so later changes to
/// the caller's buffer have no effect.
///
/// Put secrets into a storage meant for them (`SecureStorage`); the
/// diagnostics of every storage leave stored values out of release builds
/// (see `SettingsEvent`).
base class BytesSetting extends StoredSetting<Uint8List, String> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  BytesSetting({
    required SettingsStorage storage,
    required String key,
    required Uint8List defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<Uint8List>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the Base64 string.
  BytesSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(
         slot: slot,
         codec: const Base64BytesCodec(),
         equality: const ListEquality<int>().equals,
         snapshot: _frozen,
       );
}

/// Nullable bytes, stored as a Base64 string; see [BytesSetting].
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class BytesNullableSetting extends StoredNullableSetting<Uint8List, String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [BytesSetting.new].
  BytesNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    Uint8List? defaultValue,
    SettingValidator<Uint8List?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key,
  /// which holds the Base64 string.
  BytesNullableSetting.inSlot(
    SettingSlot<String> slot, {
    super.defaultValue,
    super.validator,
  }) : super(
         slot: slot,
         codec: const Base64BytesCodec(),
         equality: const ListEquality<int>().equals,
         snapshot: _frozen,
       );
}

/// An unmodifiable copy of [bytes].
Uint8List _frozen(Uint8List bytes) => Uint8List.fromList(bytes).asUnmodifiableView();
