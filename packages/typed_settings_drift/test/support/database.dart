import 'package:drift/drift.dart';
import 'package:typed_settings_drift/typed_settings_drift.dart';

part 'database.g.dart';

/// The settings table of the package tests.
class SettingTable extends Table with SettingsEntryColumns {
  @override
  String get tableName => 'setting';
}

@DriftDatabase(tables: [SettingTable])
class TestDb extends _$TestDb {
  /// A database on [executor].
  // The generated constructor parameter is named `e`, so this cannot be a super parameter.
  // ignore: use_super_parameters
  TestDb(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;
}
