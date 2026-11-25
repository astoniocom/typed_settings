# typed_settings

Type-safe, reactive application settings for Dart and Flutter, with
pluggable storage backends.

| Package | |
| --- | --- |
| [`typed_settings`](packages/typed_settings) | The core: setting presets, validation, diagnostics, in-memory and DAO storages. Pure Dart. |
| [`typed_settings_flutter`](packages/typed_settings_flutter) | Flutter bindings and Material setting tiles. |
| [`typed_settings_shared_preferences`](packages/typed_settings_shared_preferences) | SharedPreferences storage. |
| [`typed_settings_hive`](packages/typed_settings_hive) | Hive CE storage. |
| [`typed_settings_secure_storage`](packages/typed_settings_secure_storage) | flutter_secure_storage storage. |
| [`typed_settings_drift`](packages/typed_settings_drift) | drift (SQLite) storage. |
| [`typed_settings_json_schema`](packages/typed_settings_json_schema) | JSON Schema validation of map settings. |
| [`typed_settings_json_schema_flutter`](packages/typed_settings_json_schema_flutter) | JSON Schema editor of map settings in Flutter. |
| [`typed_settings_conformance`](packages/typed_settings_conformance) | The storage contract as a test suite, for backend authors. |

[`example`](example) is a Flutter application that shows every tile over
every storage.

## Development

The packages form a [pub workspace](https://dart.dev/tools/pub/workspaces):
run `dart pub get` once at the root. `typed_settings_json_schema_flutter`
needs a checkout of `json_schema_form_builder` next to this repository
until that package is published.

Licensed under the [MIT License](LICENSE).
