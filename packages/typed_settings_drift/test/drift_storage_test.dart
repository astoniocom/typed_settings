import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_dao.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';
import 'package:typed_settings_drift/typed_settings_drift.dart';

import 'support/database.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  storageConformance('DriftStorage', (observer) async {
    final database = TestDb(NativeDatabase.memory());
    final dao = DriftSettingsDao(database, database.settingTable);
    return CachedDaoStorage.create(dao: dao, observer: observer);
  });

  test('DAOs over one table share a box; the same table of another database does not', () async {
    final database = TestDb(NativeDatabase.memory());
    final other = TestDb(NativeDatabase.memory());
    addTearDown(() => Future.wait([database.close(), other.close()]));

    final storage = await CachedDaoStorage.create(dao: DriftSettingsDao(database, database.settingTable));
    await expectLater(
      CachedDaoStorage.create(dao: DriftSettingsDao(database, database.settingTable)),
      throwsStateError,
    );
    final elsewhere = await CachedDaoStorage.create(dao: DriftSettingsDao(other, other.settingTable));

    await Future.wait([storage.close(), elsewhere.close()]);
  });
}
