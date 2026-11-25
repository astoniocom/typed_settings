import 'package:drift/drift.dart';
import 'package:typed_settings/typed_settings_dao.dart';
import 'package:typed_settings_drift/src/settings_entry_columns.dart';

/// A [SettingsDao] over one drift table with [SettingsEntryColumns].
///
/// Reads and writes go through drift's query builder, typed by the mixin, so
/// the SQL names of [SettingsEntryColumns.box], [SettingsEntryColumns.key] and
/// [SettingsEntryColumns.value] live in one place. [writeBatch] runs in one
/// transaction. The drift connection queues statements, so
/// [maxConcurrentOperations] stays at one: the storage already orders writes
/// per key.
final class DriftSettingsDao<T extends SettingsEntryColumns, D> extends SettingsDao {
  /// A DAO for [table] of [database]. [table] is the generated table object
  /// (`db.settingTable`); [T] and [D] (the row class) are inferred from it.
  DriftSettingsDao(this.database, TableInfo<T, D> table)
    : _info = table,
      _box = table.asDslTable.box,
      _key = table.asDslTable.key,
      _value = table.asDslTable.value;

  /// The database that owns the table.
  final GeneratedDatabase database;

  final TableInfo<T, D> _info;

  /// The box, key and value columns as drift expressions.
  final Column<String> _box;
  final Column<String> _key;
  final Column<String> _value;

  /// One object per table of a database, so that DAOs over one table
  /// share a store and DAOs over another database do not. `TableInfo`'s
  /// own `==` cannot tell: before drift 2.35 it ignores the database.
  static final _stores = Expando<Map<String, Object>>('typed_settings_drift: settings tables');

  @override
  late final Object store = (_stores[database] ??= {}).putIfAbsent(_info.actualTableName, Object.new);

  @override
  Future<List<SettingsRow>> getByBox(String box) async {
    final query = database.selectOnly(_info)
      ..addColumns([_key, _value])
      ..where(_box.equals(box));
    final rows = await query.get();
    return [
      for (final row in rows) SettingsRow(key: row.read(_key)!, value: row.read(_value)!),
    ];
  }

  @override
  Future<void> upsert(String box, String key, String value) {
    return database
        .into(_info)
        .insertOnConflictUpdate(
          RawValuesInsertable({
            _box.name: Variable<String>(box),
            _key.name: Variable<String>(key),
            _value.name: Variable<String>(value),
          }),
        );
  }

  @override
  Future<void> deleteOne(String box, String key) {
    return (database.delete(_info)..where((_) => _box.equals(box) & _key.equals(key))).go();
  }

  @override
  Future<void> deleteByBox(String box) {
    return (database.delete(_info)..where((_) => _box.equals(box))).go();
  }

  @override
  Future<void> writeBatch(String box, {required Map<String, String> upserts, required Iterable<String> deletes}) {
    return database.transaction(() async {
      for (final entry in upserts.entries) {
        await upsert(box, entry.key, entry.value);
      }
      for (final key in deletes) {
        await deleteOne(box, key);
      }
    });
  }
}
