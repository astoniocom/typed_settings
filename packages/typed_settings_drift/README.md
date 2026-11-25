# typed_settings_drift

[drift](https://pub.dev/packages/drift) storage for
[`typed_settings`](https://pub.dev/packages/typed_settings): settings kept in a
table of your SQLite database.

drift generates code only for tables declared in your package, so the table
is yours: mix `SettingsEntryColumns` into it, which adds the `box`, `key`
and `value` columns and their primary key.

```dart
import 'package:drift/drift.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_dao.dart';
import 'package:typed_settings_drift/typed_settings_drift.dart';

part 'database.g.dart';

@DataClassName('SettingData')
class SettingTable extends Table with SettingsEntryColumns {
  @override
  String get tableName => 'setting';
}

@DriftDatabase(tables: [SettingTable])
class AppDb extends _$AppDb {
  AppDb(super.e);

  @override
  int get schemaVersion => 1;
}

Future<SettingsStorage> openSettings(AppDb db) {
  return CachedDaoStorage.create(dao: DriftSettingsDao(db, db.settingTable));
}
```

`CachedDaoStorage` loads a box into memory, so reads are synchronous, and
writes through `DriftSettingsDao` in the background; `flush()` waits for
them. Several boxes share the table; pass `box:` to `CachedDaoStorage.create`
for one other than the unnamed box, and `persistenceDelay:` to write a key
only once it has not changed for that long (or on `flush()`). Values are
stored as strings that record their type.
