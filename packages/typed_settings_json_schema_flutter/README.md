# typed_settings_json_schema_flutter

Flutter editor for [`typed_settings`](https://pub.dev/packages/typed_settings)
map settings that are checked against a JSON Schema.

[`typed_settings_json_schema`](https://pub.dev/packages/typed_settings_json_schema)
holds the setting and the validator. This package draws the editor:
`JsonSchemaMapSettingTile` and `JsonSchemaMapNullableSettingTile` edit the
map through a form generated from the schema and as raw JSON, two views of
one value. A value the schema rejects cannot be submitted.

```dart
JsonSchemaMapSettingTile(setting: settings.todoList, label: 'Todo list');
```

A map without a schema is edited with `MapSettingTile` of
[`typed_settings_flutter`](https://pub.dev/packages/typed_settings_flutter).
