import 'package:typed_settings/typed_settings.dart';

/// The value violates a JSON Schema; [messages] describe the violations.
final class JsonSchemaValidationError extends ValidationError {
  const JsonSchemaValidationError(this.messages, {super.debugDescription});

  final List<String> messages;

  @override
  List<Object?> get props => [messages, debugDescription];
}
