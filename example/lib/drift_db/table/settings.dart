import 'package:drift/drift.dart';
import 'package:typed_settings_drift/typed_settings_drift.dart';

@DataClassName('SettingData')
class SettingTable extends Table with SettingsEntryColumns {
  @override
  String get tableName => 'setting';
}
