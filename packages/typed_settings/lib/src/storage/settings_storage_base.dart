import 'package:meta/meta.dart';
import 'package:typed_settings/src/diagnostics/settings_event.dart';
import 'package:typed_settings/src/diagnostics/settings_observer.dart';
import 'package:typed_settings/src/foundation/build_mode.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/storage_kit/backend_box.dart';
import 'package:typed_settings/src/storage_kit/key_change_notifier.dart';

/// Base class for storage backends: holds the [observer], keeps the key
/// listeners (a [KeyChangeNotifier]) and provides [reportReadError], and keeps
/// the lifecycle: one open storage per box of a backend, and [close].
/// What is left to the backend is the key-level state ([remove],
/// [setNull], [hasNull], [clear], [flush], [reload]) and the typed getters and
/// setters; each of its reads and writes starts with [checkOpen].
///
/// The class is `base`, and so is every backend built on it: a backend
/// extends it (as a `base` or `final` class) and cannot implement it, so
/// that the lifecycle it keeps holds for every storage of that kind. A
/// decorator or a mock implements `SettingsStorage` itself.
abstract base class SettingsStorageBase implements SettingsStorage {
  /// [observer] receives this storage's diagnostics and those of every
  /// setting backed by this storage. It is fixed here. Without one, a [DefaultSettingsObserver] logs every
  /// event, and a debug build says once per isolate that a storage was
  /// created without one. Nothing looked up later can redirect a storage
  /// already created.
  ///
  /// [serves] is the box this storage persists to. While this storage is
  /// open, creating another one that serves the same box throws a
  /// [StateError]; see the lifecycle section of [SettingsStorage]. A
  /// storage without a backend of its own (one in memory) passes none.
  /// The box is taken once this constructor has run, and only [close]
  /// gives it back: a subclass checks its arguments in its initializer
  /// list, since a constructor body that throws leaves the box taken.
  SettingsStorageBase({
    SettingsObserver? observer,
    BackendBox? serves,
  }) : observer = observer ?? const DefaultSettingsObserver(),
       _serves = serves {
    if (serves != null && !_served.add(serves)) {
      final box = serves.name.isEmpty ? 'the unnamed box' : 'the box `${serves.name}`';
      throw StateError(
        'An open storage already serves $box of this ${serves.backend.runtimeType}: '
        'create one storage per box and share it, or close it first',
      );
    }
    if (observer == null && isDebugBuild && !_warnedOfDefaultObserver) {
      _warnedOfDefaultObserver = true;
      // A debug build only, so that the default is replaced before release.
      // ignore: avoid_print
      print(
        '${DefaultSettingsObserver.logName}: $runtimeType was created without an observer, so its '
        "diagnostics go to the device log only; pass `observer:` to route them to the application's logging. "
        'Said once per isolate.',
      );
    }
  }

  /// Whether a debug build has said that a storage was created without an
  /// observer.
  static bool _warnedOfDefaultObserver = false;

  /// Lets the next storage created without an observer say so again.
  @visibleForTesting
  static void resetDefaultObserverWarning() => _warnedOfDefaultObserver = false;

  /// The boxes an open storage of this isolate serves. Two storages over
  /// one box anywhere in the isolate would each keep their own listeners,
  /// and their settings would not see each other's writes, so the set is
  /// not one a caller could hand in or replace. [close] takes a box out.
  ///
  /// Another isolate (a background sync) has a set of its own: it may open
  /// the same box, and neither storage sees the other's writes, nor any
  /// write made outside a storage (native code), until it reloads (see
  /// [SettingsStorage.reload]). Writers are not coordinated: prefer
  /// writing a box from one isolate, and reload it where another one may
  /// have written.
  static final ServedBoxes _served = ServedBoxes();

  @override
  final SettingsObserver observer;

  final BackendBox? _serves;

  /// Completes when [close] has; `null` while the storage is open.
  Future<void>? _closing;

  /// Throws a [StateError] for [operation] once [close] has been called;
  /// every read and write of a backend calls it first.
  @protected
  void checkOpen(String operation) {
    if (_closing != null) throw StateError('$operation on a closed storage');
  }

  late final KeyChangeNotifier _keyListeners = KeyChangeNotifier(report: observer.report);

  @override
  void addKeyListener(String key, void Function() listener) {
    checkOpen('addKeyListener');
    _keyListeners.add(key, listener);
  }

  @override
  void removeKeyListener(String key, void Function() listener) => _keyListeners.remove(key, listener);

  /// Notifies the listeners of [key]; a backend calls it after every
  /// mutation of [key], before the mutator returns. See
  /// [KeyChangeNotifier.notify].
  @protected
  void notifyKeyChanged(String key) => _keyListeners.notify(key);

  /// Notifies the listeners of every key; a backend calls it from
  /// [clear] and wherever every key may have changed ([reload]).
  @protected
  void notifyAllKeysChanged() => _keyListeners.notifyAll();

  @override
  Future<void> close() => _closing ??= _close();

  @override
  bool get isClosed => _closing != null;

  /// Runs [mutations]: each write is persisted on its own. A backend that
  /// can persist a burst more cheaply overrides this (see
  /// [SettingsStorage.batch]).
  @override
  void batch(void Function() mutations) {
    checkOpen('batch');
    mutations();
  }

  Future<void> _close() async {
    try {
      await flush();
    } finally {
      final serves = _serves;
      if (serves != null) _served.remove(serves);
      await closeBackend();
    }
  }

  /// Releases what the backend holds for this storage, once the writes
  /// issued before [close] have finished (a Hive box closes). Called once,
  /// by [close]; does nothing by default.
  @protected
  Future<void> closeBackend() async {}

  /// Reports a present value under [key] that cannot be interpreted as the
  /// requested type; see the typed getter contract of [SettingsStorage].
  /// Call it where a typed getter returns `null` for such a value. [raw]
  /// travels on the event, out of its message outside debug builds; keep
  /// it out of [error]'s message too (a [FormatException]'s `source` is
  /// the place for it).
  @protected
  void reportReadError(
    String key,
    Object? raw,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    observer.report(
      StorageReadErrorEvent(
        key: key,
        raw: raw,
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }
}
