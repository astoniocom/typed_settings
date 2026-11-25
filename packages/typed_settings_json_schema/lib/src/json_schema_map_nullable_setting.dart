import 'package:json_schema_builder/json_schema_builder.dart' as jsb;
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_json_schema/src/json_schema_validator.dart';

/// A [MapNullableSetting] validated against a JSON Schema on both read and
/// write; `null` always passes the schema.
///
/// An additional [validator] runs after the schema check. See
/// [JsonSchemaValidator] for the constraints on [schema].
base class JsonSchemaMapNullableSetting extends MapNullableSetting {
  JsonSchemaMapNullableSetting({
    required super.storage,
    required super.key,
    required this.schema,
    super.legacyKeys,
    super.defaultValue,
    SettingValidator<Map<String, Object?>?>? validator,
  }) : super(validator: _withSchema(schema, validator));

  /// Creates the setting over [slot], a store of its own with no key.
  JsonSchemaMapNullableSetting.inSlot(
    super.slot, {
    required this.schema,
    super.defaultValue,
    SettingValidator<Map<String, Object?>?>? validator,
  }) : super.inSlot(validator: _withSchema(schema, validator));

  final jsb.Schema schema;

  static SettingValidator<Map<String, Object?>?> _withSchema(
    jsb.Schema schema,
    SettingValidator<Map<String, Object?>?>? validator,
  ) {
    final schemaValidator = JsonSchemaValidator<Map<String, Object?>?>(schema);
    return validator == null ? schemaValidator : SettingValidator.all([schemaValidator, validator]);
  }
}
