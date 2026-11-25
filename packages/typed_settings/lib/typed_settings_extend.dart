/// Building blocks for a setting of a new kind.
///
/// Import this library when writing a preset, a codec or a slot: a value
/// type the presets do not cover, a representation of its own, a store
/// that holds one setting. Applications that only use settings need
/// `package:typed_settings/typed_settings.dart`, which this library
/// re-exports.
///
/// * `StoredSetting`, `StoredNullableSetting`: a setting assembled from a
///   slot, a codec and optionally an equality and a snapshot; every
///   preset is one.
/// * `SettingCodec` and the built-in codecs; `ParsedStringCodec` for a
///   type that parses its own string form, `JsonObjectCodec` for a model
///   class with `fromJson` / `toJson`, and `then` to chain two codecs.
/// * `SettingSlot`, `SettingSlotBase`, `KeyedSettingSlot`: where the raw
///   value of one setting lives.
/// * `SlotState`: what a slot holds.
/// * `SettingsRegistry`: the live settings of a storage, for what spans
///   an application (a debug menu, resetting everything).
/// * `SettingViewListeners`: the listeners one `ValueNotifier` view
///   registered on a setting, removed by its own `dispose` while the
///   setting stays alive.
library;

export 'src/codec/base64_bytes_codec.dart';
export 'src/codec/calendar_date_codec.dart';
export 'src/codec/chained_codec.dart';
export 'src/codec/date_time_millis_codec.dart';
export 'src/codec/duration_millis_codec.dart';
export 'src/codec/enum_name_codec.dart';
export 'src/codec/json_list_codec.dart';
export 'src/codec/json_map_codec.dart';
export 'src/codec/json_object_codec.dart';
export 'src/codec/json_range_codec.dart';
export 'src/codec/json_set_codec.dart';
export 'src/codec/parsed_string_codec.dart';
export 'src/codec/setting_codec.dart';
export 'src/codec/uri_string_codec.dart';
export 'src/settings/setting_view_listeners.dart';
export 'src/settings/settings_registry.dart';
export 'src/settings/stored_nullable_setting.dart';
export 'src/settings/stored_setting.dart';
export 'src/slot/keyed_setting_slot.dart';
export 'src/slot/setting_slot.dart';
export 'src/slot/setting_slot_base.dart';
export 'src/slot/slot_state.dart';
export 'typed_settings.dart';
