import 'dart:async';

import 'package:meta/meta.dart';
import 'package:typed_settings/src/diagnostics/settings_event.dart';
import 'package:typed_settings/src/diagnostics/settings_observer.dart';
import 'package:typed_settings/src/foundation/listener_list.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';

/// A [SettingSlot] with no keys: listeners, a scope of its own, and
/// nothing persisted until a subclass stores it.
///
/// Extend this for a store that exists only for one setting. The subclass
/// is `final` (or itself `base`). Implement [read], [write], [writeNull]
/// and [remove], and call [notifyChanged] after a mutation that changed
/// the state, before returning. [commit] and [commitNull] write and
/// complete at once, as nothing is persisted; override them when the
/// subclass has something to wait for. Its [place] is the slot itself, so
/// two settings that read it differently are rejected.
///
/// ```dart
/// final class LocalBoolSettingSlot extends SettingSlotBase<bool> {
///   SlotState<bool> _state = AbsentSlotState<bool>();
///
///   @override
///   SlotState<bool> read() => _state;
///
///   @override
///   void write(bool raw) {
///     _state = RawSlotState(raw);
///     notifyChanged();
///   }
///
///   @override
///   void writeNull() {
///     _state = NullSlotState<bool>();
///     notifyChanged();
///   }
///
///   @override
///   void remove() {
///     if (_state is AbsentSlotState<bool>) return;
///     _state = AbsentSlotState<bool>();
///     notifyChanged();
///   }
/// }
/// ```
abstract base class SettingSlotBase<R> implements SettingSlot<R> {
  /// [observer] receives listener errors; a [DefaultSettingsObserver]
  /// unless given.
  SettingSlotBase({this.observer = const DefaultSettingsObserver()});

  @override
  final SettingsObserver observer;

  final ListenerList _listeners = ListenerList();

  @override
  SlotPlace get place => KeylessSlotPlace(this);

  @override
  Future<void> commit(R raw) {
    write(raw);
    return Future<void>.value();
  }

  @override
  Future<void> commitNull() {
    writeNull();
    return Future<void>.value();
  }

  @override
  void addListener(void Function() listener) => _listeners.add(listener);

  @override
  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Notifies the listeners, in registration order. A listener that throws
  /// is reported and skipped. A listener added during the notification is
  /// first called on the next change; one removed during it is not called
  /// any more.
  @protected
  void notifyChanged() {
    _listeners.notify(
      (error, stackTrace) => observer.report(
        ListenerErrorEvent(source: ListenerSource.slot, key: null, error: error, stackTrace: stackTrace),
      ),
    );
  }
}
