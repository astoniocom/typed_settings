import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot_base.dart';
import 'package:typed_settings/src/slot/slot_state.dart';

/// A [SettingSlot] that keeps its one value in memory and persists
/// nothing.
///
/// For tests and for a setting that is meant to be ephemeral and does not
/// share a box with others. It has no key; a preset takes it through its
/// `inSlot` constructor (`IntSetting.inSlot(InMemorySettingSlot(), ...)`).
/// `InMemoryStorage` is the shared box, which a preset takes with
/// a key.
final class InMemorySettingSlot<R extends Object> extends SettingSlotBase<R> {
  /// Creates an empty slot. [observer] receives listener errors.
  InMemorySettingSlot({super.observer});

  SlotState<R> _state = AbsentSlotState<R>();

  @override
  SlotState<R> read() => _state;

  @override
  void write(R raw) {
    _state = RawSlotState<R>(raw);
    notifyChanged();
  }

  @override
  void writeNull() {
    _state = NullSlotState<R>();
    notifyChanged();
  }

  @override
  void remove() {
    if (_state is AbsentSlotState<R>) return;
    _state = AbsentSlotState<R>();
    notifyChanged();
  }
}
