import 'package:meta/meta.dart';

/// What a slot, the place of a single raw value of type [R], holds:
/// nothing ([AbsentSlotState]), an explicit `null` ([NullSlotState]) or a
/// raw value ([RawSlotState]).
///
/// Equal states mean a setting reads the same thing.
@immutable
sealed class SlotState<R> {
  const SlotState();

  /// Whether a keyed slot read this from one of its legacy keys, because
  /// its current key is absent. Always `false` for a slot without legacy
  /// keys, and for [AbsentSlotState].
  bool get fromLegacyKey;
}

/// Nothing is stored.
final class AbsentSlotState<R> extends SlotState<R> {
  /// Creates the state.
  const AbsentSlotState();

  @override
  bool get fromLegacyKey => false;

  @override
  bool operator ==(Object other) => other is AbsentSlotState;

  @override
  int get hashCode => (AbsentSlotState).hashCode;
}

/// An explicit `null` is stored (see `SettingsStorage.setNull`).
final class NullSlotState<R> extends SlotState<R> {
  /// Creates the state; see [fromLegacyKey].
  const NullSlotState({this.fromLegacyKey = false});

  @override
  final bool fromLegacyKey;

  @override
  bool operator ==(Object other) => other is NullSlotState && other.fromLegacyKey == fromLegacyKey;

  @override
  int get hashCode => Object.hash(NullSlotState, fromLegacyKey);
}

/// [raw] is stored.
final class RawSlotState<R> extends SlotState<R> {
  /// Creates the state for [raw]; see [fromLegacyKey].
  const RawSlotState(this.raw, {this.fromLegacyKey = false});

  /// The stored raw value.
  final R raw;

  @override
  final bool fromLegacyKey;

  @override
  bool operator ==(Object other) =>
      other is RawSlotState<R> && other.raw == raw && other.fromLegacyKey == fromLegacyKey;

  @override
  int get hashCode => Object.hash(RawSlotState<R>, raw, fromLegacyKey);
}
