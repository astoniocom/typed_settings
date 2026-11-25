import 'package:flutter/widgets.dart';
import 'package:typed_settings/typed_settings.dart';

/// Formats the message about a value the setting named [settingName]
/// rejected.
typedef SettingsErrorMessageFormatter = String Function(String settingName, SettingValidationException error);

/// Reports a value a setting tile could not store because the setting
/// rejected it.
///
/// A tile finds its handler through `SettingsErrorHandlerProvider.of`,
/// which reads the provider without subscribing to it.
@immutable
abstract class SettingsErrorHandler {
  /// Allows subclasses to have const constructors.
  const SettingsErrorHandler();

  /// Reports [error], raised by the setting the tile titled [settingName]
  /// edits, from the tile's [context].
  void handleValidationError(BuildContext context, String settingName, SettingValidationException error);
}
