import 'package:meta/meta.dart';
import 'package:typed_settings/src/foundation/build_mode.dart';

/// Row-level persistence a `CachedDaoStorage` is built on; typically a
/// database table with `(box, key, value)` columns.
///
/// Every write is made from the storage's background queue: writes are
/// ordered per key, [writeBatch] runs after every write of one of its keys
/// issued before it and before any issued after, and [deleteByBox] after
/// every write issued before it and before any issued after. Calls over
/// distinct keys overlap only when [maxConcurrentOperations] allows it.
///
/// The class is `base`: a DAO extends it (as a `base` or `final` class)
/// and cannot implement it. [store] and the four row operations are
/// abstract, [writeBatch] has a default that an implementation with
/// transactions should override.
abstract base class SettingsDao {
  /// Allows `const` subclasses.
  const SettingsDao();

  /// What this DAO persists to, compared with `==`: DAOs with equal stores
  /// share their boxes, so that one open storage at a time serves a box
  /// of a table however many DAO objects reach it (see the lifecycle
  /// section of `SettingsStorage`).
  ///
  /// Name the table, not the DAO: the table object of the database
  /// connection (a drift `TableInfo`), or a value naming the database file
  /// and the table. Two DAO objects over one table that name different
  /// stores would each get a storage with its own cache, and one would
  /// overwrite the other's writes unnoticed. Only a DAO that is the table
  /// itself (one that keeps the rows in memory) returns `this`.
  ///
  /// An object is held weakly while a storage serves it; a string, a
  /// number or a record is held until the storage is closed.
  Object get store;

  /// How many calls over distinct keys the storage may make at once, so
  /// that a slow write of one key does not hold the others back. Calls
  /// over one key, [deleteByBox] and [writeBatch] keep their order either
  /// way. One by default: the calls are made one at a time. Raise it for a
  /// DAO that handles concurrent calls (a database that queues them on its
  /// connection).
  int get maxConcurrentOperations => 1;

  /// All rows of [box]; called when the storage is created and by each
  /// `SettingsStorage.reload`. A reload calls it once the writes issued
  /// before it have finished, outside the write queue: writes issued
  /// meanwhile may overlap it, and the storage keeps their state whatever
  /// this returns for their keys.
  Future<List<SettingsRow>> getByBox(String box);

  /// Inserts or replaces the row `(box, key)`.
  Future<void> upsert(String box, String key, String value);

  /// Deletes the row `(box, key)`; a no-op when it does not exist.
  Future<void> deleteOne(String box, String key);

  /// Deletes every row of [box] in one operation (`DELETE ... WHERE box = ?`).
  Future<void> deleteByBox(String box);

  /// Applies the writes of one `SettingsStorage.batch` to [box]: [upserts]
  /// by key, then [deletes]; a key appears in at most one of them.
  /// Override to run them in a single transaction; the default issues
  /// [upsert] and [deleteOne] one after another.
  Future<void> writeBatch(String box, {required Map<String, String> upserts, required Iterable<String> deletes}) async {
    for (final entry in upserts.entries) {
      await upsert(box, entry.key, entry.value);
    }
    for (final key in deletes) {
      await deleteOne(box, key);
    }
  }
}

/// One `(key, value)` row of a box, as returned by [SettingsDao.getByBox].
/// A plain value object: two rows with the same key and value are equal.
@immutable
final class SettingsRow {
  /// Creates a row.
  const SettingsRow({
    required this.key,
    required this.value,
  });

  /// The setting key within its box.
  final String key;

  /// The stored string.
  final String value;

  @override
  bool operator ==(Object other) => other is SettingsRow && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(key, value);

  /// The row with its [value] in debug builds only: the value is stored
  /// data, which may be a secret, as diagnostics treat it (see
  /// `SettingsEvent`).
  @override
  String toString() => isDebugBuild ? 'SettingsRow($key: $value)' : 'SettingsRow($key)';
}
