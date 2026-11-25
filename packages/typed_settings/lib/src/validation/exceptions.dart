import 'package:typed_settings/src/validation/validation_errors.dart';

/// Thrown by the value setter and `commit` when the validator rejects the
/// new value. Nothing has been persisted, cached or notified.
final class SettingValidationException implements Exception {
  /// Creates the exception for the setting labelled [diagnosticKey] rejecting a
  /// value for [error]. [diagnosticKey] is null when the storage has no key.
  const SettingValidationException(this.diagnosticKey, this.error);

  /// Diagnostic label of the setting that rejected the value. See
  /// `ReadOnlySetting.diagnosticKey`. Not an address: nothing looks the setting
  /// up by it.
  final String? diagnosticKey;

  /// Why the value was rejected.
  final ValidationError error;

  @override
  String toString() => diagnosticKey == null
      ? 'SettingValidationException: $error'
      : 'SettingValidationException(`$diagnosticKey`): $error';
}
