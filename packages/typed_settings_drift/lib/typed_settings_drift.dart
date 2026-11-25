/// Drift storage for typed_settings.
///
/// A database mixes `SettingsEntryColumns` into its own table and keeps that
/// database class. `DriftSettingsDao` reads and writes one box of the table.
library;

export 'src/drift_settings_dao.dart';
export 'src/settings_entry_columns.dart';
