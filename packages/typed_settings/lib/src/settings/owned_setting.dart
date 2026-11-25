import 'package:typed_settings/src/settings/setting.dart';

/// A [Setting] as its owner holds it: the code that created the setting,
/// and so decides when it is no longer needed.
///
/// Hand the setting on as a [Setting] or a `ReadOnlySetting`, so that the
/// code that edits or reads it cannot end its life. Every preset is one;
/// `SettingsOwner` disposes the ones it owns together.
abstract interface class OwnedSetting<T> implements Setting<T> {
  /// Releases what the setting holds: its listeners, its stream and its
  /// registration with the storage. The setting must not be used
  /// afterwards: its other operations throw a [StateError].
  void dispose();
}
