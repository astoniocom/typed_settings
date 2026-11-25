import 'package:typed_settings/src/codec/uri_string_codec.dart';
import 'package:typed_settings/src/settings/stored_nullable_setting.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';

/// A [Uri] setting, stored in its string form.
base class UriSetting extends StoredSetting<Uri, String> {
  /// Creates the setting stored under [key] of [storage]. [legacyKeys] are
  /// the keys it was stored under before, most recent first (see
  /// [KeyedSettingSlot]).
  UriSetting({
    required SettingsStorage storage,
    required String key,
    required Uri defaultValue,
    List<String> legacyKeys = const [],
    SettingValidator<Uri>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  UriSetting.inSlot(
    SettingSlot<String> slot, {
    required super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const UriStringCodec());
}

/// A nullable [Uri] setting, stored in its string form.
///
/// `null` is stored as an explicit null, distinct from nothing stored,
/// which yields [defaultValue].
base class UriNullableSetting extends StoredNullableSetting<Uri, String> {
  /// Creates the setting stored under [key] of [storage]; see
  /// [UriSetting.new].
  UriNullableSetting({
    required SettingsStorage storage,
    required String key,
    List<String> legacyKeys = const [],
    Uri? defaultValue,
    SettingValidator<Uri?>? validator,
  }) : this.inSlot(
         KeyedSettingSlot.ofString(storage, key: key, legacyKeys: legacyKeys),
         defaultValue: defaultValue,
         validator: validator,
       );

  /// Creates the setting over [slot], a store of its own with no key.
  UriNullableSetting.inSlot(
    SettingSlot<String> slot, {
    super.defaultValue,
    super.validator,
  }) : super(slot: slot, codec: const UriStringCodec());
}
