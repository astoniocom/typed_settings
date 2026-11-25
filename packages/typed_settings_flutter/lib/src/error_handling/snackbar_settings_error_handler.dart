import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';

String _defaultMessage(BuildContext context, String settingName, SettingValidationException error) {
  final sentence = TypedSettingsLocalizations.of(context).validationMessage(error.error);
  return '$settingName: $sentence';
}

/// Reports a rejected value in a snack bar of the nearest
/// [ScaffoldMessenger].
///
/// Without one, reports it with [DialogSettingsErrorHandler], using the
/// same [formatMessage], so the rejection is still shown.
@immutable
final class SnackbarSettingsErrorHandler extends SettingsErrorHandler {
  /// Creates a handler that words its messages with [formatMessage].
  const SnackbarSettingsErrorHandler({
    this.formatMessage,
  });

  /// Words the message. When null, the setting name and
  /// [TypedSettingsLocalizations.validationMessage] for the error. That
  /// sentence does not include the rejected value.
  final SettingsErrorMessageFormatter? formatMessage;

  @override
  void handleValidationError(BuildContext context, String settingName, SettingValidationException error) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      DialogSettingsErrorHandler(formatMessage: formatMessage).handleValidationError(context, settingName, error);
      return;
    }
    final message = formatMessage?.call(settingName, error) ?? _defaultMessage(context, settingName, error);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Reports a rejected value in an alert dialog.
///
/// The handler a tile uses when no `SettingsErrorHandlerProvider` is above
/// it. [SnackbarSettingsErrorHandler] uses it too when no [ScaffoldMessenger]
/// is above the tile.
@immutable
final class DialogSettingsErrorHandler extends SettingsErrorHandler {
  /// Creates a handler that words its messages with [formatMessage].
  const DialogSettingsErrorHandler({
    this.formatMessage,
  });

  /// Words the message. When null, the setting name and
  /// [TypedSettingsLocalizations.validationMessage] for the error. That
  /// sentence does not include the rejected value.
  final SettingsErrorMessageFormatter? formatMessage;

  @override
  void handleValidationError(BuildContext context, String settingName, SettingValidationException error) {
    final message = formatMessage?.call(settingName, error) ?? _defaultMessage(context, settingName, error);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
          ),
        ],
      ),
    );
  }
}
