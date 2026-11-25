import 'package:drift/drift.dart';

/// The columns a drift table needs to hold typed_settings rows: mix it into
/// a table declared in your project.
///
/// drift's generator only understands table classes in the package it runs
/// in, so the table itself is yours; the mixin is the columns and their
/// primary key. The table's name is yours too.
///
/// ```dart
/// @DataClassName('SettingData')
/// class SettingTable extends Table with SettingsEntryColumns {
///   @override
///   String get tableName => 'setting';
/// }
/// ```
///
/// `(box, key)` is the primary key. [box] defaults to an empty string, the
/// unnamed box. `DriftSettingsDao` fills the three columns.
mixin SettingsEntryColumns on Table {
  /// The box a row belongs to. The unnamed box is an empty string.
  TextColumn get box => text().withDefault(const Constant(''))();

  /// The setting key within [box].
  TextColumn get key => text()();

  /// The stored string.
  TextColumn get value => text()();

  @override
  Set<Column<Object>>? get primaryKey => {box, key};
}
