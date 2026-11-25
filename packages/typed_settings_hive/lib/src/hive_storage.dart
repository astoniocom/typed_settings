import 'package:hive_ce/hive_ce.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_backend.dart';

/// A [SettingsStorage] over a Hive [Box]. Scalars and explicit `null`
/// use Hive's native value types.
///
/// A non-lazy [Box] updates its in-memory map inside `put`/`delete`/
/// `deleteAll` and persists in the background, serialising writes in call
/// order. Without a persistence delay the storage makes each call right
/// away and only hands the future to [BackgroundPersistence.track], so
/// the mutation contract holds. With a delay, a single-key write updates
/// what this storage reads at once and calls `put` or `delete` only when
/// the delay passes, or when `flush`, `commit` or `close` starts it.
/// Reading the [Box] directly meanwhile still sees the previous value.
///
/// One open storage at a time may serve a [Box] (see the lifecycle section
/// of `SettingsStorage`); Hive hands out one [Box] object per open box, so
/// this covers every storage over the box. [close] closes the box too.
base class HiveStorage extends SettingsStorageBase {
  /// A storage over [box], which must be open; a [StateError] when an open
  /// storage already serves it. An [ArgumentError] when [persistenceDelay]
  /// is zero or negative.
  ///
  /// [persistenceDelay] holds each single-key write and keeps only the
  /// latest value of that key, until the duration has passed without a
  /// newer write. Reads of this storage see the new value at once.
  /// `flush`, `commit` and `close` start a held write instead of waiting
  /// the duration out.
  HiveStorage({
    required Box<dynamic> box,
    super.observer,
    Duration? persistenceDelay,
  }) : _box = box,
       _persistence = BackgroundPersistence(
         report: (observer ?? const DefaultSettingsObserver()).report,
         persistenceDelay: persistenceDelay,
       ),
       super(serves: BackendBox(box, box.name));

  /// Opens the Hive box named [box] and returns the storage over it. Hive
  /// reads the whole box into memory, so the cost grows with that box
  /// alone (see the loading section of `SettingsStorage`). `Hive.init`
  /// (or `Hive.initFlutter` of hive_ce_flutter) must have run. A
  /// [StateError] when an open storage already serves the box. An
  /// [ArgumentError] when [persistenceDelay] is zero or negative; see
  /// [HiveStorage.new].
  static Future<HiveStorage> create({
    required String box,
    SettingsObserver? observer,
    Duration? persistenceDelay,
  }) async {
    final hiveBox = await Hive.openBox<dynamic>(box);
    return HiveStorage(box: hiveBox, observer: observer, persistenceDelay: persistenceDelay);
  }

  final Box<dynamic> _box;

  final BackgroundPersistence _persistence;

  /// Values this storage reads that the box does not hold yet, because a
  /// [HiveStorage.new]'s persistence delay has not handed the write over.
  /// [_absent] is a removal. Empty when there is no delay.
  final Map<String, _Ahead> _ahead = {};

  bool get _delays => _persistence.persistenceDelay != null;

  /// The name of the Hive box this storage serves.
  String get box => _box.name;

  @override
  Future<void> flush({Iterable<String>? keys}) => _persistence.flush(keys: keys);

  /// Reads [key] as [T]; a value of another type is reported and read as
  /// absent.
  T? _get<T>(String key) {
    checkOpen('read of `$key`');
    final raw = _read(key);
    if (raw == null) return null;
    if (raw is T) return raw as T;
    reportReadError(
      key,
      raw,
      FormatException('Expected $T, got ${raw.runtimeType}'),
    );
    return null;
  }

  /// The value a read of [key] sees: the write a delay still holds, or
  /// what the box holds. Null both for absence and for an explicit null;
  /// [hasNull] tells them apart.
  Object? _read(String key) {
    final ahead = _ahead[key];
    if (ahead != null) return identical(ahead.value, _absent) ? null : ahead.value;
    return _box.get(key);
  }

  void _put(String key, Object? value) {
    checkOpen('write of `$key`');
    if (!_delays) {
      _persistence.track(PersistTarget.key(key), _box.put(key, value));
    } else {
      final generation = _stamp();
      _ahead[key] = _Ahead(value, generation);
      _persistence.persist(PersistTarget.key(key), () async {
        await _box.put(key, value);
        _forget(key, generation);
      });
    }
    notifyKeyChanged(key);
  }

  /// Numbers the writes held ahead of the box across every key, so that a
  /// number is never given twice, even once a key's entry was dropped.
  int _generation = 0;

  int _stamp() => ++_generation;

  /// Drops the held value of [key] when [generation] is still the latest
  /// one, so a write that finished late does not hide a newer value.
  void _forget(String key, int generation) {
    final ahead = _ahead[key];
    if (ahead != null && ahead.generation == generation) _ahead.remove(key);
  }

  @override
  bool? getBool(String key) => _get<bool>(key);

  @override
  void setBool(String key, bool value) => _put(key, value);

  @override
  int? getInt(String key) => _get<int>(key);

  @override
  void setInt(String key, int value) => _put(key, value);

  @override
  double? getDouble(String key) => _get<double>(key);

  @override
  void setDouble(String key, double value) => _put(key, value);

  @override
  String? getString(String key) => _get<String>(key);

  @override
  void setString(String key, String value) => _put(key, value);

  @override
  void remove(String key) {
    checkOpen('remove of `$key`');
    if (!_delays) {
      _persistence.track(PersistTarget.key(key), _box.delete(key));
    } else {
      final generation = _stamp();
      _ahead[key] = _Ahead(_absent, generation);
      _persistence.persist(PersistTarget.key(key), () async {
        await _box.delete(key);
        _forget(key, generation);
      });
    }
    notifyKeyChanged(key);
  }

  // Hive stores `null` natively; `containsKey` tells it apart from absence.
  @override
  void setNull(String key) => _put(key, null);

  @override
  bool hasNull(String key) {
    checkOpen('read of `$key`');
    final ahead = _ahead[key];
    if (ahead != null) return !identical(ahead.value, _absent) && ahead.value == null;
    return _box.containsKey(key) && _box.get(key) == null;
  }

  @override
  Iterable<String> get keys {
    checkOpen('read of keys');
    final boxKeys = _box.keys.whereType<String>();
    if (_ahead.isEmpty) return List.unmodifiable(boxKeys);
    return List.unmodifiable({
      for (final key in boxKeys)
        if (_ahead[key] == null || !identical(_ahead[key]!.value, _absent)) key,
      for (final MapEntry(:key, :value) in _ahead.entries)
        if (!identical(value.value, _absent)) key,
    });
  }

  /// Deletes every key with one `deleteAll`. `Box.clear` is not used: it
  /// empties the in-memory map only after the file has been truncated,
  /// which would break the mutation contract.
  @override
  Future<void> clear() {
    checkOpen('clear');
    if (!_delays) {
      _persistence.track(PersistTarget.all(_box.name), _box.deleteAll(_box.keys.toList(growable: false)));
    } else {
      final generation = _stamp();
      for (final key in keys) {
        _ahead[key] = _Ahead(_absent, generation);
      }
      // Runs after the single-key writes already queued, which `flush`
      // starts at once. Deleting the box's keys then, rather than the
      // list from this call, also drops a key those writes just put.
      _persistence.persist(PersistTarget.all(_box.name), () async {
        await _box.deleteAll(_box.keys.toList(growable: false));
        _ahead.removeWhere((_, ahead) => ahead.generation == generation);
      });
    }
    notifyAllKeysChanged();
    return flush();
  }

  /// Completes without a change: Hive has no call that reads an open box
  /// again, and on the VM nothing else can have written it, since Hive
  /// holds an exclusive lock on the box file while the box is open. On
  /// the web there is no such lock: a box that another tab writes is not
  /// reloaded, and has to be closed and opened again.
  @override
  Future<void> reload() async {
    checkOpen('reload');
    await _persistence.pendingOperationsSettled();
  }

  @override
  Future<void> closeBackend() => _box.close();
}

/// A value this storage reads ahead of the box, and which write it belongs
/// to. A later write of the key gets a greater [generation].
final class _Ahead {
  _Ahead(this.value, this.generation);

  /// The value, or [_absent] when the key was removed.
  final Object? value;
  final int generation;
}

/// Marks a removal in [_Ahead.value]. Distinct from an explicit null.
const Object _absent = Object();
