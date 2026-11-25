/// The contracts of a setting, without anything that stores one.
///
/// Depend on this where a setting is only read, written or observed: a
/// domain type, a use case, a widget that renders a value. It exports
/// `ReadOnlySetting` and `Setting`, validation, and the exception a
/// `commit` fails with, with the `PersistErrorEvent`s it carries. It does
/// not export a preset, a storage or the rest of the diagnostics, so that
/// code cannot reach the persistence layer through the import.
///
/// The code that puts the application together, creating storages and
/// settings, imports `package:typed_settings/typed_settings.dart`, which
/// re-exports this library.
///
/// A setting is a `ValueListenable` of `package:listen`. This library does
/// not export that name. Flutter before 3.50 declares a `ValueListenable`
/// and a `Listenable` of its own, and a file that imports both would not
/// compile where it uses either. Flutter code takes the names from
/// Flutter, pure Dart code from `package:listen/listen.dart`.
library;

export 'src/diagnostics/settings_event.dart' show PersistErrorEvent;
export 'src/diagnostics/settings_persist_exception.dart';
export 'src/settings/setting.dart';
export 'src/validation/exceptions.dart';
export 'src/validation/setting_validator.dart';
export 'src/validation/validation_errors.dart';
