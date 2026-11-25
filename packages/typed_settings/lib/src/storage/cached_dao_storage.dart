import 'package:typed_settings/src/diagnostics/settings_observer.dart';
import 'package:typed_settings/src/storage/settings_dao.dart';
import 'package:typed_settings/src/storage/string_backed_storage.dart';
import 'package:typed_settings/src/storage_kit/backend_box.dart';

/// A [StringBackedStorage] over a [SettingsDao] (typically a database
/// table). One instance serves one [box]; the whole box is loaded into
/// memory by [create], the only way to obtain an instance.
///
/// One open storage at a time may serve a box of one store (see the
/// lifecycle section of `SettingsStorage`). DAOs are told apart by their
/// [SettingsDao.store], which names the table they write to.
final class CachedDaoStorage extends StringBackedStorage {
  CachedDaoStorage._({
    required SettingsDao dao,
    required this.box,
    required super.cache,
    super.observer,
    super.persistenceDelay,
  }) : _dao = dao,
       super(
         serves: BackendBox(dao.store, box),
         maxConcurrentOperations: dao.maxConcurrentOperations,
       );

  /// Loads [box] from [dao] into memory and returns the storage over it:
  /// one [SettingsDao.getByBox] query, whose cost grows with that box
  /// alone (see the loading section of `SettingsStorage`). A [StateError]
  /// when an open storage already serves [box] of the store of [dao].
  ///
  /// [persistenceDelay] holds each single-key write and keeps only the
  /// latest value of that key, until the duration has passed without a
  /// newer write. Reads see the new value at once. `flush`, `commit` and
  /// `close` start a held write instead of waiting the duration out. An
  /// [ArgumentError] when it is zero or negative.
  static Future<CachedDaoStorage> create({
    required SettingsDao dao,
    String box = '',
    SettingsObserver? observer,
    Duration? persistenceDelay,
  }) async {
    return CachedDaoStorage._(
      dao: dao,
      box: box,
      observer: observer,
      persistenceDelay: persistenceDelay,
      cache: await _load(dao, box),
    );
  }

  static Future<Map<String, String>> _load(SettingsDao dao, String box) async => {
    for (final row in await dao.getByBox(box)) row.key: row.value,
  };

  final SettingsDao _dao;

  /// The box this storage serves; passed to every [SettingsDao] call.
  final String box;

  /// Reads the box again with one [SettingsDao.getByBox] query.
  @override
  Future<Map<String, String>> loadRaw() => _load(_dao, box);

  @override
  Future<void> writeRaw(String key, String value) => _dao.upsert(box, key, value);

  @override
  Future<void> deleteRaw(String key) => _dao.deleteOne(box, key);

  /// Hands the writes of a `batch` to [SettingsDao.writeBatch], so a DAO
  /// with transactions applies them in one.
  @override
  Future<void> writeBatchRaw(Map<String, String> upserts, Iterable<String> deletes) =>
      _dao.writeBatch(box, upserts: upserts, deletes: deletes);

  /// Clears the box with a single [SettingsDao.deleteByBox] call instead
  /// of one delete per key. The call is a barrier in the write queue, so
  /// writes issued before it land first and writes issued after it are not
  /// wiped.
  @override
  Future<void> clear() {
    checkOpen('clear');
    return clearAtOnce(box, () => _dao.deleteByBox(box));
  }
}
