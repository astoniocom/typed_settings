import 'dart:async';

import 'package:typed_settings/src/diagnostics/settings_observer.dart';
import 'package:typed_settings/src/diagnostics/settings_persist_exception.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/slot/slot_state.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';

/// One key of a shared box, as a [SettingSlot]: of one of the four raw
/// types every [SettingsStorage] holds ([ofBool], [ofInt], [ofDouble],
/// [ofString]), or of a type a storage holds in addition (the unnamed
/// constructor).
///
/// A preset builds it from its `storage`, `key` and `legacyKeys`. Create
/// one directly for a `StoredSetting` with a codec of its own.
///
/// [legacyKeys] are the keys the value was stored under before [key],
/// most recent first. An [ArgumentError] reports a list that contains
/// [key]. Reads fall back to the first legacy key that holds something;
/// writes go to [key] only. The slot drops the legacy keys once a write
/// or a commit of [key] has persisted, and on removal. Keep a legacy key
/// listed for as long as an installation may still hold it: a value that
/// is never rewritten keeps being read from it.
///
/// Listeners of this slot are listeners of [key] and of every legacy
/// key on the box, so `clear()` and a write through another setting over
/// the same key notify them. Its [place] is the key of the box, not this
/// object: two slots over one key of one box still meet there, and a
/// conflict is reported against that box.
final class KeyedSettingSlot<R> implements SettingSlot<R> {
  /// The raw value of type [R] under [key] of [storage], read with
  /// [getRaw] and written with [setRaw]: the typed getter and setter of
  /// [storage] for [R]. [legacyKeys] must not contain [key].
  ///
  /// For the four types of [SettingsStorage], [ofBool], [ofInt],
  /// [ofDouble] and [ofString] pass them. A storage that holds a type of
  /// its own declares it in an interface that extends [SettingsStorage],
  /// with a getter that follows the typed getter contract, and a preset
  /// over that interface passes its pair:
  ///
  /// ```dart
  /// KeyedSettingSlot(
  ///   storage,
  ///   key: key,
  ///   getRaw: storage.getLatLon,
  ///   setRaw: storage.setLatLon,
  ///   legacyKeys: legacyKeys,
  /// )
  /// ```
  ///
  /// Explicit `null`, removal and the key listeners go through
  /// [storage] itself, so they need nothing from the type.
  KeyedSettingSlot(
    this.storage, {
    required this.key,
    required R? Function(String key) getRaw,
    required void Function(String key, R raw) setRaw,
    List<String> legacyKeys = const [],
  }) : legacyKeys = List.unmodifiable(legacyKeys),
       _getRaw = getRaw,
       _setRaw = setRaw {
    if (legacyKeys.contains(key)) {
      throw ArgumentError.value(legacyKeys, 'legacyKeys', 'must not contain the current key `$key`');
    }
  }

  /// The `bool` [storage] holds under [key]. [legacyKeys] must not contain
  /// [key].
  static KeyedSettingSlot<bool> ofBool(
    SettingsStorage storage, {
    required String key,
    List<String> legacyKeys = const [],
  }) => KeyedSettingSlot(storage, key: key, legacyKeys: legacyKeys, getRaw: storage.getBool, setRaw: storage.setBool);

  /// The `int` [storage] holds under [key]. [legacyKeys] must not contain
  /// [key].
  static KeyedSettingSlot<int> ofInt(
    SettingsStorage storage, {
    required String key,
    List<String> legacyKeys = const [],
  }) => KeyedSettingSlot(storage, key: key, legacyKeys: legacyKeys, getRaw: storage.getInt, setRaw: storage.setInt);

  /// The `double` [storage] holds under [key]. [legacyKeys] must not
  /// contain [key].
  static KeyedSettingSlot<double> ofDouble(
    SettingsStorage storage, {
    required String key,
    List<String> legacyKeys = const [],
  }) =>
      KeyedSettingSlot(storage, key: key, legacyKeys: legacyKeys, getRaw: storage.getDouble, setRaw: storage.setDouble);

  /// The `String` [storage] holds under [key]. [legacyKeys] must not
  /// contain [key].
  static KeyedSettingSlot<String> ofString(
    SettingsStorage storage, {
    required String key,
    List<String> legacyKeys = const [],
  }) =>
      KeyedSettingSlot(storage, key: key, legacyKeys: legacyKeys, getRaw: storage.getString, setRaw: storage.setString);

  /// The shared box the keys are on.
  final SettingsStorage storage;

  /// The key of the shared box this value is stored under.
  final String key;

  /// Former keys, most recent first. Empty when there are none. A copy of
  /// the list given, which the slot cannot see change.
  final List<String> legacyKeys;

  final R? Function(String key) _getRaw;

  final void Function(String key, R raw) _setRaw;

  final List<({void Function() listener, void Function() onKey})> _listeners = [];

  /// Every key whose state determines the value: [key], then the
  /// [legacyKeys].
  Iterable<String> get _keys => [key, ...legacyKeys];

  @override
  SettingsObserver get observer => storage.observer;

  @override
  SlotPlace get place => KeyedSlotPlace(storage, key: key, legacyKeys: legacyKeys);

  /// The state of [key], or, when [key] is absent, of the first legacy key
  /// holding a value or an explicit `null`, marked
  /// [SlotState.fromLegacyKey]. A present value [storage] cannot interpret
  /// as [R] reads as absent; the storage reports it itself.
  @override
  SlotState<R> read() {
    final current = _readKey(key);
    if (current is! AbsentSlotState<R>) return current;
    for (final legacyKey in legacyKeys) {
      switch (_readKey(legacyKey)) {
        case AbsentSlotState():
          continue;
        case NullSlotState():
          return NullSlotState<R>(fromLegacyKey: true);
        case RawSlotState(:final raw):
          return RawSlotState<R>(raw, fromLegacyKey: true);
      }
    }
    return current;
  }

  SlotState<R> _readKey(String key) {
    if (storage.hasNull(key)) return NullSlotState<R>();
    final raw = _getRaw(key);
    return raw == null ? AbsentSlotState<R>() : RawSlotState<R>(raw);
  }

  @override
  void write(R raw) {
    _setRaw(key, raw);
    _removeLegacyOncePersisted();
  }

  @override
  void writeNull() {
    storage.setNull(key);
    _removeLegacyOncePersisted();
  }

  /// Removes the legacy keys that still hold something once [key] has
  /// persisted, without waiting for it. A write that does not persist
  /// leaves them, so that the next start still reads the value there.
  void _removeLegacyOncePersisted() {
    if (!legacyKeys.any((legacyKey) => _readKey(legacyKey) is! AbsentSlotState<R>)) return;
    unawaited(
      _persistThenRemoveLegacy().then(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          // A write that did not persist was reported to the storage's
          // observer when it failed, and keeping the legacy keys is the
          // point; any other error is a bug and stays uncaught.
          if (error is! SettingsPersistException) Error.throwWithStackTrace(error, stackTrace);
        },
      ),
    );
  }

  @override
  Future<void> commit(R raw) {
    _setRaw(key, raw);
    return _persistThenRemoveLegacy();
  }

  @override
  Future<void> commitNull() {
    storage.setNull(key);
    return _persistThenRemoveLegacy();
  }

  /// Waits for [key] to persist, then removes the legacy keys. A storage
  /// closed meanwhile keeps them: the key, which reads first, holds the
  /// value already.
  Future<void> _persistThenRemoveLegacy() async {
    await storage.flush(keys: [key]);
    if (!storage.isClosed) _removeLegacy();
  }

  /// Removes the legacy keys that still hold something, then [key] when it
  /// holds something. A no-op when nothing is stored, so that a `reset` of
  /// an already absent key does not enqueue a delete.
  ///
  /// The legacy keys go first: a removal that persists only in part then
  /// leaves the value under [key] as it was before, not an older value
  /// under a legacy key that would resurface. A storage that batches
  /// persists the removals together.
  @override
  void remove() {
    void removeAll() {
      _removeLegacy();
      if (_readKey(key) is! AbsentSlotState<R>) storage.remove(key);
    }

    storage.batch(removeAll);
  }

  /// Removes the legacy keys that still hold something.
  void _removeLegacy() {
    for (final legacyKey in legacyKeys) {
      if (_readKey(legacyKey) is! AbsentSlotState<R>) storage.remove(legacyKey);
    }
  }

  @override
  void addListener(void Function() listener) {
    void onKey() => listener();
    final attached = <String>[];
    try {
      for (final watched in _keys) {
        storage.addKeyListener(watched, onKey);
        attached.add(watched);
      }
    } on Object {
      for (final watched in attached) {
        storage.removeKeyListener(watched, onKey);
      }
      rethrow;
    }
    _listeners.add((listener: listener, onKey: onKey));
  }

  @override
  void removeListener(void Function() listener) {
    final index = _listeners.indexWhere((entry) => entry.listener == listener);
    if (index < 0) return;
    final onKey = _listeners.removeAt(index).onKey;
    for (final watched in _keys) {
      storage.removeKeyListener(watched, onKey);
    }
  }
}
