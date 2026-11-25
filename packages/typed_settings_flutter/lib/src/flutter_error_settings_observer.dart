import 'package:flutter/foundation.dart';
import 'package:typed_settings/typed_settings.dart';

/// Hands every event to [FlutterError.reportError].
///
/// Every event means user data was lost or replaced (a stored value that
/// could not be used, a write that never reached the disk), so it should
/// be visible in every build mode. [FlutterError.reportError] prints to the
/// console in debug builds and in release builds invokes
/// [FlutterError.onError], which crash reporters (Sentry, Crashlytics)
/// hook into.
///
/// What reaches [FlutterError] leaves the user's stored data out except in
/// debug builds: the context is the event's message and the exception its
/// [SettingsEvent.reportableError] (see [SettingsEvent]).
///
/// Pass it as `observer:` to each storage. A storage holds the observer it
/// was created with, so there is no process-wide default to install: a
/// test or another engine cannot redirect a storage already created, and
/// a storage created without this observer keeps printing to the console.
base class FlutterErrorSettingsObserver extends SettingsObserver {
  /// Creates the observer; stateless, so prefer the `const` form.
  const FlutterErrorSettingsObserver();

  @override
  void onEvent(SettingsEvent event) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: event.reportableError,
        stack: event.stackTrace,
        library: 'typed_settings',
        context: ErrorDescription(event.message),
      ),
    );
  }
}
