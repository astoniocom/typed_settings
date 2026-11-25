import 'package:meta/meta.dart';

/// The listeners of one thing that changes: a key of a storage, a slot, a
/// setting.
///
/// A listener added twice is called twice, and [remove] takes out one of
/// its registrations. [notify] calls the listeners registered when it
/// starts, in the order they were added, less those removed while it
/// runs: a listener that disposes what owns another one keeps that one
/// from being called on a disposed owner. One added while it runs is
/// first called by the next [notify].
@internal
final class ListenerList {
  final List<_Registration> _registrations = [];

  bool get isEmpty => _registrations.isEmpty;

  void add(void Function() listener) => _registrations.add(_Registration(listener));

  /// Takes out the earliest registration of [listener]; a no-op when it
  /// has none.
  void remove(void Function() listener) {
    final index = _registrations.indexWhere((registration) => registration.listener == listener);
    if (index >= 0) _registrations.removeAt(index).removed = true;
  }

  /// Takes out every registration, those a running [notify] has yet to
  /// reach included.
  void clear() {
    for (final registration in _registrations) {
      registration.removed = true;
    }
    _registrations.clear();
  }

  /// Calls the listeners; a throwing one goes to [onError] and the next
  /// ones are still called.
  void notify(void Function(Object error, StackTrace stackTrace) onError) {
    for (final registration in List.of(_registrations)) {
      if (registration.removed) continue;
      try {
        registration.listener();
        // Deliberately catches Errors too, as Flutter's ChangeNotifier does:
        // the change is already applied, so a bug in one listener must
        // neither undo it nor hide it from the other listeners.
        // ignore: avoid_catches_without_on_clauses
      } catch (error, stackTrace) {
        onError(error, stackTrace);
      }
    }
  }
}

final class _Registration {
  _Registration(this.listener);

  final void Function() listener;

  bool removed = false;
}
