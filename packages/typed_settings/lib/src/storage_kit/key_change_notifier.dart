import 'package:meta/meta.dart';
import 'package:typed_settings/src/diagnostics/settings_event.dart';
import 'package:typed_settings/src/foundation/listener_list.dart';

/// The key listener registry of a `SettingsStorage`. The storage owns one,
/// forwards `addKeyListener` and `removeKeyListener` of the contract to
/// [add] and [remove], and calls [notify] and [notifyAll] after each
/// mutation, per the mutation contract.
///
/// `SettingsStorageBase` owns one; a storage implemented from the
/// interface directly can own one as well.
final class KeyChangeNotifier {
  /// A registry that hands a listener that throws to [report] as a
  /// [ListenerErrorEvent]: the storage's `observer.report`.
  KeyChangeNotifier({required void Function(SettingsEvent event) report}) : _report = report;

  final void Function(SettingsEvent event) _report;

  final Map<String, ListenerList> _keyListeners = {};

  /// See `SettingsStorage.addKeyListener`.
  void add(String key, void Function() listener) {
    _keyListeners.putIfAbsent(key, ListenerList.new).add(listener);
  }

  /// See `SettingsStorage.removeKeyListener`.
  void remove(String key, void Function() listener) {
    final listeners = _keyListeners[key];
    if (listeners == null) return;
    listeners.remove(listener);
    if (listeners.isEmpty) _keyListeners.remove(key);
  }

  /// Notifies the listeners of [key]; the storage calls it after every
  /// mutation of [key]. A throwing listener is reported and skipped, so a
  /// mutator never fails because of a listener and every listener sees
  /// every change. The listeners are those registered when it is called,
  /// less those removed while it runs.
  void notify(String key) {
    _keyListeners[key]?.notify(
      (error, stackTrace) => _report(
        ListenerErrorEvent(source: ListenerSource.storageKey, key: key, error: error, stackTrace: stackTrace),
      ),
    );
  }

  /// Notifies the listeners of every key; the storage calls it from
  /// `clear`.
  void notifyAll() => List.of(_keyListeners.keys).forEach(notify);

  /// The keys that have a listener, as they are now.
  @visibleForTesting
  List<String> get listenedKeys => List.of(_keyListeners.keys);
}
