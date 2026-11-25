/// JSON Schema editor for typed_settings map settings.
///
/// `typed_settings_json_schema` supplies the setting and the validator.
/// This library supplies the tiles that edit one: a generated form and a
/// raw JSON view of the same value. A map without a schema is edited with
/// `MapSettingTile` from `typed_settings_flutter`.
library;

export 'src/json_schema_map_nullable_setting_tile.dart';
export 'src/json_schema_map_setting_tile.dart';
