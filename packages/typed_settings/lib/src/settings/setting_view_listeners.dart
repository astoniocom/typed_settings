import 'package:listen/listen.dart';
import 'package:typed_settings/src/settings/setting.dart';

/// The listeners one setting view registered on its setting.
///
/// [dispose] removes them from the setting. It does not dispose the
/// setting. The views of `Setting.asValueNotifier` and of `editorView` in
/// `typed_settings_flutter` each use one.
final class SettingViewListeners {
  final List<VoidCallback> _listeners = [];
  var _disposed = false;

  /// Whether this view has a listener that [dispose] has not removed.
  bool get hasListeners {
    checkUsable('hasListeners');
    return _listeners.isNotEmpty;
  }

  /// Registers [listener] on this view and on [setting].
  void add(ReadOnlySetting<Object?> setting, VoidCallback listener) {
    checkUsable('addListener');
    setting.addListener(listener);
    _listeners.add(listener);
  }

  /// Undoes one [add] of [listener]. A no-op after [dispose].
  ///
  /// The listener is removed from [setting] even when this view did not
  /// add it. A rebuilt widget keeps the subscription of the first view and
  /// unsubscribes through an equal view created later, whose list is
  /// empty.
  void remove(ReadOnlySetting<Object?> setting, VoidCallback listener) {
    if (_disposed) return;
    _listeners.remove(listener);
    setting.removeListener(listener);
  }

  /// Removes every listener this view added. The setting stays usable.
  /// Disposing again fails in debug mode and does nothing otherwise.
  void dispose(ReadOnlySetting<Object?> setting) {
    assert(!_disposed, 'dispose on a disposed setting view');
    if (_disposed) return;
    _listeners.forEach(setting.removeListener);
    _listeners.clear();
    _disposed = true;
  }

  /// Calls the listeners this view still has, in registration order.
  ///
  /// A listener that throws is handed to [Listenable.onError] with
  /// [ErrorContext.listener], the same way a `ChangeNotifier` reports one.
  /// Flutter's binding reports that through `FlutterError` and returns, so
  /// the remaining listeners are still called. The default callback
  /// rethrows, which stops the notification.
  void notify() {
    checkUsable('notifyListeners');
    for (final listener in List<VoidCallback>.of(_listeners)) {
      if (!_listeners.contains(listener)) continue;
      try {
        listener();
      } on Object catch (error, stackTrace) {
        Listenable.onError(error, stackTrace, ErrorContext.listener);
      }
    }
  }

  /// Throws [StateError] when this view has been disposed.
  void checkUsable(String operation) {
    if (_disposed) throw StateError('$operation on a disposed setting view');
  }
}
