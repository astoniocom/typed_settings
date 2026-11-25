import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:typed_settings_example/drift_db/table/settings.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    SettingTable,
  ],
)
class AppDb extends _$AppDb {
  AppDb() : super(_connect());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _connect() {
    return driftDatabase(
      name: 'typed_settings',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
