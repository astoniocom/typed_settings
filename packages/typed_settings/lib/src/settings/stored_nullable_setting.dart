import 'package:meta/meta.dart';
import 'package:typed_settings/src/codec/setting_codec.dart';
import 'package:typed_settings/src/diagnostics/settings_observer.dart';
import 'package:typed_settings/src/settings/stored_setting.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/slot/slot_state.dart';

/// A [StoredSetting] whose value may be `null`.
///
/// `null` is a value in its own right, distinct from "nothing stored":
///
/// * assigning `null` persists an explicit `null` (`SettingsStorage.setNull`)
///   and reads back as `null`, also after [invalidate] or an app restart;
/// * [reset] removes the stored value, so [value] returns [defaultValue]
///   again, which may itself be non-null.
///
/// This is a preset, not a specialisation: [slot] is wrapped so that
/// the explicit `null` is presented as the raw value `null`, and the given
/// codec, equality and snapshot are lifted to `T?` with `null` mapping to
/// `null`. The given [codec] handles the non-null case only; `null` never
/// reaches it.
base class StoredNullableSetting<T extends Object, R extends Object> extends StoredSetting<T?, R?> {
  /// Assembles a nullable setting; [codec] handles the non-null case only.
  StoredNullableSetting({
    required SettingCodec<T, R> codec,
    required SettingSlot<R> slot,
    super.defaultValue,
    bool Function(T a, T b)? equality,
    T Function(T value)? snapshot,
    super.validator,
  }) : super(
         codec: _NullableCodec(codec),
         slot: _NullableSettingSlot(slot),
         equality: equality == null ? null : (a, b) => a == null || b == null ? a == b : equality(a, b),
         snapshot: snapshot == null ? null : (value) => value == null ? null : snapshot(value),
       );

  /// The given codec, which the lifting to `T?` only wraps.
  @internal
  @override
  Type get codecType => (codec as _NullableCodec<T, R>).inner.runtimeType;
}

/// Lifts a codec for [T] to `T?`, mapping `null` to `null` in both
/// directions; [_NullableSettingSlot] turns that raw `null` into the
/// slot's explicit `null`.
class _NullableCodec<T extends Object, R extends Object> implements SettingCodec<T?, R?> {
  const _NullableCodec(this.inner);

  final SettingCodec<T, R> inner;

  @override
  T? decode(R? raw) => raw == null ? null : inner.decode(raw);

  @override
  R? encode(T? value) => value == null ? null : inner.encode(value);
}

/// Presents the explicit `null` of the wrapped slot as the raw value
/// `null`, so that a nullable setting handles `null` like any other value.
///
/// Absence stays distinct, which is what lets a nullable setting tell
/// "the user chose nothing" (reads as `null`) from "nothing stored"
/// (reads as the default).
class _NullableSettingSlot<R extends Object> implements SettingSlot<R?> {
  _NullableSettingSlot(this._inner);

  final SettingSlot<R> _inner;

  @override
  SettingsObserver get observer => _inner.observer;

  @override
  SlotPlace get place => _inner.place;

  @override
  SlotState<R?> read() => switch (_inner.read()) {
    AbsentSlotState<R>() => AbsentSlotState<R?>(),
    NullSlotState<R>(:final fromLegacyKey) => RawSlotState<R?>(null, fromLegacyKey: fromLegacyKey),
    RawSlotState<R>(:final raw, :final fromLegacyKey) => RawSlotState<R?>(raw, fromLegacyKey: fromLegacyKey),
  };

  @override
  void write(R? raw) {
    if (raw == null) {
      _inner.writeNull();
    } else {
      _inner.write(raw);
    }
  }

  @override
  void writeNull() => _inner.writeNull();

  @override
  Future<void> commit(R? raw) => raw == null ? _inner.commitNull() : _inner.commit(raw);

  @override
  Future<void> commitNull() => _inner.commitNull();

  @override
  void remove() => _inner.remove();

  @override
  void addListener(void Function() listener) => _inner.addListener(listener);

  @override
  void removeListener(void Function() listener) => _inner.removeListener(listener);
}
