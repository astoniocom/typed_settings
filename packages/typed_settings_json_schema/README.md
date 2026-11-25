# typed_settings_json_schema

JSON Schema validation for [`typed_settings`](https://pub.dev/packages/typed_settings)
map settings, built on
[`json_schema_builder`](https://pub.dev/packages/json_schema_builder). Pure
Dart.

```dart
final todos = JsonSchemaMapNullableSetting(
  storage: storage,
  key: 'todos',
  schema: Schema.fromMap({
    'type': 'object',
    'required': ['items'],
  }),
);
```

`JsonSchemaMapSetting` and `JsonSchemaMapNullableSetting` check the map
against the schema on every write and on every read: a stored map that no
longer matches falls back to the default and is reported. A rejection is a
`JsonSchemaValidationError` with the messages of the violations.
`JsonSchemaValidator` attaches the same check to any map setting, alone or
combined with other checks through `SettingValidator.all`.

Validation is synchronous: every `$ref` in the schema must resolve without
fetching. A reference that would require I/O is reported as a
`JsonSchemaValidationError` rather than passing silently.

The Flutter editor for these settings is
[`typed_settings_json_schema_flutter`](https://pub.dev/packages/typed_settings_json_schema_flutter).
