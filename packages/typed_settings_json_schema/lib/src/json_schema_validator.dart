import 'package:json_schema_builder/json_schema_builder.dart' as jsb;
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_json_schema/src/json_schema_validation_error.dart';

/// Validates a map against a JSON Schema on read and write.
///
/// [T] is `Map<String, Object?>` or its nullable form; `null` is accepted,
/// whether `null` is allowed at all is the setting's concern.
///
/// Validation is synchronous, so every `$ref` in [schema] must resolve
/// without fetching; a reference that would require I/O is reported as a
/// [JsonSchemaValidationError] instead of passing silently.
final class JsonSchemaValidator<T extends Map<String, Object?>?> extends SettingValidator<T> {
  JsonSchemaValidator(this.schema) : super(_check(schema));

  final jsb.Schema schema;

  static ValueCheck<T> _check<T extends Map<String, Object?>?>(jsb.Schema schema) {
    return (value) {
      if (value == null) return null;
      try {
        final errors = schema.validateSync(value);
        if (errors.isEmpty) return null;
        return JsonSchemaValidationError([for (final error in errors) error.toString()]);
      } on jsb.SchemaResolutionRequiredException catch (e) {
        return JsonSchemaValidationError(
          ['Schema reference requires fetching and cannot be validated synchronously: $e'],
        );
      }
    };
  }
}
