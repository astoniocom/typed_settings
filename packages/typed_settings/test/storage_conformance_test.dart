import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_backend.dart';
import 'package:typed_settings/typed_settings_dao.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

final class _MemoryDao extends SettingsDao {
  final Map<String, String> rows = {};

  @override
  Object get store => this;

  @override
  Future<List<SettingsRow>> getByBox(String box) async => [
    for (final e in rows.entries) SettingsRow(key: e.key, value: e.value),
  ];

  @override
  Future<void> upsert(String box, String key, String value) async => rows[key] = value;

  @override
  Future<void> deleteOne(String box, String key) async => rows.remove(key);

  @override
  Future<void> deleteByBox(String box) async => rows.clear();
}

final class _MemoryStringBackend extends StringBackedStorage {
  _MemoryStringBackend({super.observer, super.persistenceDelay}) : super(cache: {});

  @override
  Future<Map<String, String>> loadRaw() async => Map.of(disk);

  final Map<String, String> disk = {};

  @override
  Future<void> writeRaw(String key, String value) async => disk[key] = value;

  @override
  Future<void> deleteRaw(String key) async => disk.remove(key);
}

/// Implements the storage contract directly, without [SettingsStorageBase],
/// by forwarding to another storage: the shape of a decorator or a mock.
/// Passing the conformance suite shows the contract is implementable.
class _Forwarding implements SettingsStorage {
  _Forwarding(this.inner);

  final SettingsStorage inner;

  @override
  SettingsObserver get observer => inner.observer;

  @override
  void addKeyListener(String key, void Function() listener) => inner.addKeyListener(key, listener);

  @override
  void removeKeyListener(String key, void Function() listener) => inner.removeKeyListener(key, listener);

  @override
  bool? getBool(String key) => inner.getBool(key);
  @override
  void setBool(String key, bool value) => inner.setBool(key, value);
  @override
  int? getInt(String key) => inner.getInt(key);
  @override
  void setInt(String key, int value) => inner.setInt(key, value);
  @override
  double? getDouble(String key) => inner.getDouble(key);
  @override
  void setDouble(String key, double value) => inner.setDouble(key, value);
  @override
  String? getString(String key) => inner.getString(key);
  @override
  void setString(String key, String value) => inner.setString(key, value);
  @override
  void remove(String key) => inner.remove(key);
  @override
  void setNull(String key) => inner.setNull(key);
  @override
  bool hasNull(String key) => inner.hasNull(key);
  @override
  Iterable<String> get keys => inner.keys;
  @override
  Future<void> clear() => inner.clear();
  @override
  Future<void> flush({Iterable<String>? keys}) => inner.flush(keys: keys);
  @override
  Future<void> reload() => inner.reload();
  @override
  Future<void> close() => inner.close();

  @override
  bool get isClosed => inner.isClosed;

  @override
  void batch(void Function() mutations) => inner.batch(mutations);
}

/// A storage built from the interface plus a [KeyChangeNotifier] alone, to
/// show the listener registry is reusable without the base class.
class _FromScratch implements SettingsStorage {
  _FromScratch(this.observer);

  @override
  final SettingsObserver observer;

  late final KeyChangeNotifier _keyListeners = KeyChangeNotifier(report: observer.report);

  final Map<String, Object?> _store = {};

  Future<void>? _closing;

  void _checkOpen() {
    if (_closing != null) throw StateError('closed');
  }

  T? _get<T extends Object>(String key) {
    _checkOpen();
    final raw = _store[key];
    if (raw == null) return null;
    if (raw is T) return raw;
    observer.report(StorageReadErrorEvent(key: key, raw: raw, error: FormatException('Expected $T')));
    return null;
  }

  void _set(String key, Object? value) {
    _checkOpen();
    _store[key] = value;
    _keyListeners.notify(key);
  }

  @override
  void addKeyListener(String key, void Function() listener) {
    _checkOpen();
    _keyListeners.add(key, listener);
  }

  @override
  void removeKeyListener(String key, void Function() listener) => _keyListeners.remove(key, listener);

  @override
  bool? getBool(String key) => _get<bool>(key);
  @override
  void setBool(String key, bool value) => _set(key, value);
  @override
  int? getInt(String key) => _get<int>(key);
  @override
  void setInt(String key, int value) => _set(key, value);
  @override
  double? getDouble(String key) => _get<double>(key);
  @override
  void setDouble(String key, double value) => _set(key, value);
  @override
  String? getString(String key) => _get<String>(key);
  @override
  void setString(String key, String value) => _set(key, value);
  @override
  void remove(String key) {
    _checkOpen();
    _store.remove(key);
    _keyListeners.notify(key);
  }

  @override
  void setNull(String key) => _set(key, null);
  @override
  bool hasNull(String key) {
    _checkOpen();
    return _store.containsKey(key) && _store[key] == null;
  }

  @override
  Iterable<String> get keys {
    _checkOpen();
    return List.of(_store.keys);
  }

  @override
  Future<void> clear() async {
    _checkOpen();
    _store.clear();
    _keyListeners.notifyAll();
  }

  @override
  Future<void> flush({Iterable<String>? keys}) async {}

  @override
  Future<void> reload() async => _checkOpen();

  @override
  Future<void> close() => _closing ??= Future.value();

  @override
  bool get isClosed => _closing != null;

  @override
  void batch(void Function() mutations) => mutations();
}

void main() {
  storageConformance('InMemoryStorage', (observer) async => InMemoryStorage(observer: observer));
  storageConformance(
    'a storage implementing the contract by forwarding',
    (observer) async => _Forwarding(InMemoryStorage(observer: observer)),
  );
  storageConformance(
    'a storage built from the interface and KeyChangeNotifier',
    (observer) async => _FromScratch(observer),
  );
  // The dao of the storage each test runs against, which a write made
  // outside the storage goes to.
  late _MemoryDao dao;
  Future<void> writeToDao(String key, int? value) async {
    if (value == null) {
      dao.rows.remove(key);
    } else {
      dao.rows[key] = encodeStoredInt(value);
    }
  }

  storageConformance(
    'CachedDaoStorage',
    (observer) => CachedDaoStorage.create(dao: dao = _MemoryDao(), observer: observer),
    writeOutside: (_, key, value) => writeToDao(key, value),
  );
  Future<void> writeToDisk(SettingsStorage storage, String key, int? value) async {
    final disk = (storage as _MemoryStringBackend).disk;
    if (value == null) {
      disk.remove(key);
    } else {
      disk[key] = encodeStoredInt(value);
    }
  }

  storageConformance(
    'StringBackedStorage',
    (observer) async => _MemoryStringBackend(observer: observer),
    writeOutside: writeToDisk,
  );
  // A delay no test sits out: every operation that has to reach the
  // backend must start the held writes itself.
  storageConformance(
    'StringBackedStorage with a persistence delay',
    (observer) async => _MemoryStringBackend(observer: observer, persistenceDelay: const Duration(hours: 1)),
    writeOutside: writeToDisk,
  );
  storageConformance(
    'CachedDaoStorage with a persistence delay',
    (observer) => CachedDaoStorage.create(
      dao: dao = _MemoryDao(),
      observer: observer,
      persistenceDelay: const Duration(hours: 1),
    ),
    writeOutside: (_, key, value) => writeToDao(key, value),
  );

  group('CachedDaoStorage persistence', () {
    test('values of every type survive a reload from the dao', () async {
      final dao = _MemoryDao();
      final storage = await CachedDaoStorage.create(dao: dao)
        ..setBool('b', true)
        ..setInt('i', 7)
        ..setDouble('d', 2.5)
        ..setString('s', 'text')
        ..setNull('n');
      await storage.close();

      final reloaded = await CachedDaoStorage.create(dao: dao);
      expect(reloaded.getBool('b'), isTrue);
      expect(reloaded.getInt('i'), 7);
      expect(reloaded.getDouble('d'), 2.5);
      expect(reloaded.getString('s'), 'text');
      expect(reloaded.hasNull('n'), isTrue);
    });
  });
}
