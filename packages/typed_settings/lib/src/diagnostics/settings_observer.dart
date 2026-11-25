import 'dart:async';
import 'dart:developer' as developer;

import 'package:meta/meta.dart';
import 'package:typed_settings/src/diagnostics/settings_event.dart';

/// Receives the diagnostics of settings and storages.
///
/// Pass one to a storage (`observer:` on every backend), or to a slot with
/// no key. It is fixed for that storage's lifetime, and the settings using
/// the storage report through it. One object handed to each storage
/// covers an application. A storage created without one uses
/// a [DefaultSettingsObserver], so an event is never dropped for lack of
/// configuration. There is no process-wide observer to replace: a test or
/// another engine cannot redirect a storage already created.
///
/// Settings and storages hand every event to [report], which passes it
/// to [onEvent]. Switch over the sealed [SettingsEvent] there to treat
/// one kind of event apart: the compiler then names a kind added later.
/// An observer that forwards to others (multicast, filtering) calls their
/// [report]. An [onEvent] that throws does not disturb the setting or
/// storage that reported (see [report]).
///
/// The class is `base`: an observer extends it (as a `base` or `final`
/// class) and cannot implement it, so that every observer reports through
/// the one [report], which never throws. A test records events with a
/// subclass whose [onEvent] keeps them.
abstract base class SettingsObserver {
  /// Allows `const` subclasses.
  const SettingsObserver();

  /// Receives every event reported to this observer.
  void onEvent(SettingsEvent event);

  /// Entry point for reporting: hands [event] to [onEvent].
  ///
  /// Never throws. An [onEvent] that throws is a bug of the observer, and
  /// the code that reports is in the middle of something it must finish:
  /// a read falling back to a default, a storage notifying the rest of
  /// its listeners. The error goes to the current zone's uncaught error
  /// handler instead (in Flutter, `PlatformDispatcher.onError`; in a test,
  /// a failure of the test).
  @nonVirtual
  void report(SettingsEvent event) {
    try {
      onEvent(event);
      // Deliberately catches Errors too: whatever the observer throws, the
      // reporting code must go on.
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stackTrace) {
      Zone.current.handleUncaughtError(error, stackTrace);
    }
  }
}

/// The observer a storage uses when none is passed to it: each event goes
/// to `dart:developer`'s [developer.log] as a structured record (the name
/// `typed_settings`, a level, the reportable error and the stack trace),
/// and as one line to [print].
///
/// Every event means user data was lost or replaced (a stored value that
/// could not be used, a write that never reached the disk), so it must be
/// visible with no configuration at all. [developer.log] reaches DevTools
/// and the IDE with the error and stack trace attached, but nothing at all
/// without a debugger: a release build, a `dart run` program. The line
/// printed is what such a build has, and ends up in the device log. The
/// message leaves stored data out except in debug builds (see
/// [SettingsEvent]).
///
/// It is not a good final choice for a shipped application, where
/// nobody watches the device log: pass an observer that reaches the
/// application's logging to each storage. A Flutter application passes
/// `FlutterErrorSettingsObserver` from `typed_settings_flutter`. In a
/// debug build a storage created without one says so, once.
final class DefaultSettingsObserver extends SettingsObserver {
  /// Creates the observer; stateless, so prefer the `const` form.
  const DefaultSettingsObserver();

  /// The name the records are logged under.
  static const String logName = 'typed_settings';

  @override
  void onEvent(SettingsEvent event) {
    developer.log(
      event.message,
      name: logName,
      level: _level(event),
      error: event.reportableError,
      stackTrace: event.stackTrace,
    );
    // The line is what a build without a debugger shows; see the class docs.
    // ignore: avoid_print
    print('$logName: ${event.message}');
  }

  /// `SEVERE` for a listener that threw, which is a bug; `WARNING` for the
  /// events the library recovered from on its own.
  static int _level(SettingsEvent event) => switch (event) {
    ListenerErrorEvent() => 1000,
    ReadFallbackEvent() || StorageReadErrorEvent() || PersistErrorEvent() => 900,
  };
}

/// Writes every event to the console with [print]: the message, then the
/// stack trace when there is one. The message leaves stored data out
/// except in debug builds (see [SettingsEvent]), since a release build's
/// console ends up in the device log. For a program whose console is its
/// log; [DefaultSettingsObserver] also logs a structured record.
final class PrintSettingsObserver extends SettingsObserver {
  /// Creates the observer; stateless, so prefer the `const` form.
  const PrintSettingsObserver();

  @override
  void onEvent(SettingsEvent event) {
    // The whole point of this observer is to print; see the class docs.
    // ignore: avoid_print
    print('typed_settings: ${event.message}');
    final stackTrace = event.stackTrace;
    // ignore: avoid_print
    if (stackTrace != null) print(stackTrace);
  }
}
