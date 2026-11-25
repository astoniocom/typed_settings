import 'package:flutter/widgets.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/snackbar_settings_error_handler.dart';

/// Gives the setting tiles below it the [handler] that reports the values
/// their settings reject.
///
/// Tiles read the handler when a value is rejected, without subscribing,
/// so replacing [handler] rebuilds nothing.
class SettingsErrorHandlerProvider extends InheritedWidget {
  /// Creates a provider of [handler] for [child].
  const SettingsErrorHandlerProvider({
    required this.handler,
    required super.child,
    super.key,
  });

  /// The handler the tiles below report to.
  final SettingsErrorHandler handler;

  /// The handler of the nearest provider above [context], or a
  /// [DialogSettingsErrorHandler] when there is none.
  ///
  /// Does not subscribe [context] to the provider, so it is safe to call
  /// from an event handler. An unmounted [context] also yields the dialog
  /// handler; there is no provider to read. Callers that show UI must check
  /// [BuildContext.mounted] first.
  static SettingsErrorHandler of(BuildContext context) {
    return maybeOf(context) ?? const DialogSettingsErrorHandler();
  }

  /// The handler of the nearest provider above [context], or null when
  /// there is none or [context] is unmounted.
  ///
  /// Does not subscribe [context] to the provider.
  static SettingsErrorHandler? maybeOf(BuildContext context) {
    if (!context.mounted) return null;
    return context.getInheritedWidgetOfExactType<SettingsErrorHandlerProvider>()?.handler;
  }

  @override
  bool updateShouldNotify(SettingsErrorHandlerProvider oldWidget) => false;
}
