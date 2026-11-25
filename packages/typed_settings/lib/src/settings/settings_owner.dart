import 'dart:async';

import 'package:typed_settings/src/settings/owned_setting.dart';

/// Owns settings and disposes them together.
///
/// A setting stays registered with its slot and its storage until it is
/// disposed, so one that nobody disposes lives as long as the storage
/// does. Give the class that creates settings for one purpose (the
/// settings of an application, of a screen, of a feature) an owner, pass
/// each setting it creates through [own], and call [dispose] when that
/// purpose ends: in the class's own `dispose`, or a `State.dispose`.
///
/// ```dart
/// class AppSettings {
///   AppSettings(this.storage);
///
///   final SettingsStorage storage;
///   final _settings = SettingsOwner();
///
///   late final volume = _settings.own(IntSetting(storage: storage, key: 'volume', defaultValue: 5));
///
///   void dispose() => _settings.dispose();
/// }
/// ```
///
/// A setting created lazily (a `late final` field) is owned from its
/// first use; one never used is never created. Do not dispose an owned
/// setting yourself.
final class SettingsOwner {
  final List<OwnedSetting<Object?>> _owned = [];

  var _settingsDisposed = false;

  /// Takes [setting] over, to be disposed by [dispose], and returns it.
  /// A [StateError] once [dispose] has run, since the setting would never
  /// be disposed.
  T own<T extends OwnedSetting<Object?>>(T setting) {
    if (_settingsDisposed) {
      setting.dispose();
      throw StateError('own() after dispose(): the setting would never be disposed');
    }
    _owned.add(setting);
    return setting;
  }

  /// Disposes every owned setting, the latest first. Owning another one
  /// afterwards is a [StateError]; calling this again does nothing.
  ///
  /// Every setting is disposed even when the disposal of one throws (in a
  /// debug build, a setting that was already disposed by hand): the first
  /// such error is thrown once all of them are disposed, and any further
  /// one goes to the current zone's uncaught error handler.
  void dispose() {
    if (_settingsDisposed) return;
    _settingsDisposed = true;
    (Object, StackTrace)? first;
    for (final setting in _owned.reversed) {
      try {
        setting.dispose();
        // Deliberately catches Errors too (a failed assertion is one): a
        // setting that fails to dispose must not leave the others
        // registered with their storage. Nothing is dropped: the errors
        // are rethrown or reported below.
        // ignore: avoid_catches_without_on_clauses
      } catch (error, stackTrace) {
        if (first == null) {
          first = (error, stackTrace);
        } else {
          Zone.current.handleUncaughtError(error, stackTrace);
        }
      }
    }
    _owned.clear();
    if (first case (final error, final stackTrace)) Error.throwWithStackTrace(error, stackTrace);
  }
}
