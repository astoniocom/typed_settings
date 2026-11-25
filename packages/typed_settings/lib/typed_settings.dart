/// Settings for an application: the presets, the storage contracts, the
/// diagnostics and migrations.
///
/// Re-exports `typed_settings_contract.dart`. A storage that holds the
/// data is a further library (`typed_settings_in_memory.dart`,
/// `typed_settings_dao.dart`, or a backend package); each storage that
/// can hold several boxes takes the box it serves when it is created.
///
/// What builds a setting of a new kind (`StoredSetting`, codecs, slots,
/// the registry) is in `typed_settings_extend.dart`;
/// what builds a storage is in `typed_settings_backend.dart`.
library;

export 'src/diagnostics/settings_event.dart';
export 'src/diagnostics/settings_observer.dart';
export 'src/foundation/value_range.dart';
export 'src/settings/owned_setting.dart';
export 'src/settings/presets/bool_setting.dart';
export 'src/settings/presets/bytes_setting.dart';
export 'src/settings/presets/date_setting.dart';
export 'src/settings/presets/date_time_setting.dart';
export 'src/settings/presets/double_setting.dart';
export 'src/settings/presets/duration_setting.dart';
export 'src/settings/presets/enum_set_setting.dart';
export 'src/settings/presets/enum_setting.dart';
export 'src/settings/presets/freeze.dart';
export 'src/settings/presets/int_list_setting.dart';
export 'src/settings/presets/int_setting.dart';
export 'src/settings/presets/json_setting.dart';
export 'src/settings/presets/list_setting.dart';
export 'src/settings/presets/map_setting.dart';
export 'src/settings/presets/range_setting.dart';
export 'src/settings/presets/set_setting.dart';
export 'src/settings/presets/string_list_setting.dart';
export 'src/settings/presets/string_set_setting.dart';
export 'src/settings/presets/string_setting.dart';
export 'src/settings/presets/uri_setting.dart';
export 'src/settings/settings_migrator.dart';
export 'src/settings/settings_owner.dart';
export 'src/storage/settings_storage.dart';
export 'typed_settings_contract.dart';
