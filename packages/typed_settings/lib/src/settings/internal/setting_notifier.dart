import 'dart:async';

import 'package:meta/meta.dart';
import 'package:typed_settings/src/foundation/listener_list.dart';

/// The observable side of a setting: its listeners, their notification
/// and the stream view of `ReadOnlySetting`. The setting owns one, calls
/// [notify] after each change and [close] from its `dispose`.
///
/// Listeners are notified synchronously, in registration order. A listener
/// that throws is handed to `onListenerError` and the remaining listeners
/// are still notified: the change has already been applied, so every
/// listener must see it.
///
/// [asStream] is one broadcast stream until [close]. Each subscription
/// starts with the value `read` gives at that moment, then follows
/// [notify]. [close] ends every subscription; the last subscriber leaving
/// does not.
@internal
final class SettingNotifier<T> {
  /// A notifier of the value [read] gives, which reports a listener that
  /// throws to [onListenerError].
  SettingNotifier({
    required T Function() read,
    required void Function(Object error, StackTrace stackTrace) onListenerError,
  }) : _read = read,
       _onListenerError = onListenerError;

  final T Function() _read;
  final void Function(Object error, StackTrace stackTrace) _onListenerError;

  final ListenerList _listeners = ListenerList();

  /// The one stream [asStream] returns. Created on the first call:
  /// cancelling its subscriptions does not close it, so a later `listen`
  /// on the same instance works.
  Stream<T>? _stream;

  /// The controllers of the subscriptions currently on [_stream]. Each
  /// gets the value at the moment it subscribes, then every later change.
  final Set<MultiStreamController<T>> _streamControllers = {};

  bool _closed = false;

  /// Calls [listener] on every [notify]; see `ReadOnlySetting.addListener`.
  void add(void Function() listener) => _listeners.add(listener);

  /// Undoes one [add] of [listener].
  void remove(void Function() listener) => _listeners.remove(listener);

  /// Notifies the listeners, in registration order. A listener added
  /// during the notification is first called on the next change; one
  /// removed during it is not called any more, nor is any once a listener
  /// closes this notifier.
  void notify() => _listeners.notify(_onListenerError);

  /// The broadcast stream of the value; see the class documentation.
  Stream<T> asStream() => _stream ??= Stream<T>.multi(_onStreamListen, isBroadcast: true);

  /// Subscribes [controller]. It receives the current value (or the error
  /// reading it throws), then every later [notify], until the caller
  /// cancels or this notifier is closed.
  ///
  /// Reading the value here runs inside the controller's `onListen`, and a
  /// throw from there would escape as an uncaught zone error
  /// (`StreamController` guards `onListen`). The subscriber is the caller
  /// of `listen`, so the failure is an error on this subscription instead.
  void _onStreamListen(MultiStreamController<T> controller) {
    if (_closed) {
      unawaited(controller.close());
      return;
    }

    _streamControllers.add(controller);
    if (_streamControllers.length == 1) add(_emitToStreams);
    controller.onCancel = () => _cancelStream(controller);
    _emit(controller);
  }

  /// [notify] happened while somebody is subscribed: send what the value
  /// is now. One read for every subscriber, so they all observe the same
  /// value. A throw is a failure of the read, forwarded like
  /// [_onStreamListen] does, and not a bug in a listener.
  void _emitToStreams() {
    final controllers = [
      for (final controller in _streamControllers)
        if (!controller.isClosed) controller,
    ];
    if (controllers.isEmpty) return;

    final T current;
    try {
      current = _read();
    } on Object catch (error, stackTrace) {
      for (final controller in controllers) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
      return;
    }
    for (final controller in controllers) {
      controller.add(current);
    }
  }

  /// Sends the current value to one new subscriber. See [_emitToStreams]
  /// for why a throw becomes a stream error.
  void _emit(MultiStreamController<T> controller) {
    if (controller.isClosed) return;
    try {
      controller.add(_read());
    } on Object catch (error, stackTrace) {
      if (!controller.isClosed) controller.addError(error, stackTrace);
    }
  }

  /// Drops [controller]. The last one also drops [_emitToStreams], so a
  /// setting nobody listens to does not re-read on every change. Closing
  /// the controller ends this subscription only; [_stream] stays open.
  void _cancelStream(MultiStreamController<T> controller) {
    _streamControllers.remove(controller);
    if (_streamControllers.isEmpty) remove(_emitToStreams);
    if (!controller.isClosed) unawaited(controller.close());
  }

  /// Drops every listener and ends every subscription; a later `listen`
  /// on [asStream] ends at once. Closing again does nothing.
  void close() {
    if (_closed) return;
    _closed = true;
    final controllers = List<MultiStreamController<T>>.of(_streamControllers);
    _streamControllers.clear();
    _listeners.clear();
    for (final controller in controllers) {
      if (!controller.isClosed) unawaited(controller.close());
    }
  }
}
