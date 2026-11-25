import 'dart:async';

import 'package:meta/meta.dart';
import 'package:typed_settings/src/diagnostics/settings_observer.dart';
import 'package:typed_settings/src/slot/slot_state.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';

/// Persistence of exactly one setting: one raw value of type [R].
///
/// Three states ([SlotState]), the same ones a key of a [SettingsStorage]
/// has: absent, an explicit `null`, or a raw value. A setting does not
/// know which kind of slot it is over. A `KeyedSettingSlot` is one key,
/// and its former keys, of a shared box. A slot that exists only for this
/// setting implements this directly, or extends `SettingSlotBase`.
///
/// Former keys are the slot's own business: it reads through them while
/// the current place is absent (marking the state
/// [SlotState.fromLegacyKey]), moves the value off them on a write, and
/// removes them with the value. A setting only asks for writes, commits
/// and removal.
///
/// Mutations update the stored state and notify listeners synchronously,
/// before they return, so a setting over this slot reads the new value
/// from inside the mutation. Notifying includes a change made through
/// another setting over the same place, a migration, or `clear()` of a
/// shared box. A listener that throws does not stop the mutation or the
/// other listeners; `SettingSlotBase` and a keyed slot (through the
/// box) do this. A mutation that changes nothing does not notify, so a
/// `reset` of a value that is already absent is silent.
///
/// [commit] completes when this setting's value has reached the backend.
/// A keyed slot waits for its key only.
abstract interface class SettingSlot<R> {
  /// Diagnostics of this slot and of the setting over it. A keyed slot
  /// returns the storage's observer.
  SettingsObserver get observer;

  /// The stored state. When the current place is absent and a former key
  /// holds a value or an explicit `null`, that state, marked
  /// [SlotState.fromLegacyKey]. A slot without former keys never marks it.
  SlotState<R> read();

  /// Stores [raw], replacing whatever was stored. A slot with former keys
  /// writes the current one and removes the former ones once it has
  /// persisted, without waiting for that: the value has moved, and a
  /// write that does not persist leaves it under a former key. How long
  /// the storage holds the backend write is the storage's persistence
  /// delay, not a parameter of the slot.
  void write(R raw);

  /// Stores an explicit `null`, distinct from absence, like [write]. A
  /// non-nullable setting never calls this; a nullable one does, for
  /// `null`.
  void writeNull();

  /// Stores [raw] like [write], and completes once it has reached the
  /// backend; fails the way `SettingsStorage.flush` fails when it has not.
  ///
  /// A slot with former keys removes them only once the value is
  /// persisted, so that a write that does not persist leaves the value
  /// under a former key for the next start instead of losing both. A
  /// keyed slot waits for its own key only, so another key's failure does
  /// not fail the future. A slot that persists nothing completes at once.
  Future<void> commit(R raw);

  /// Stores an explicit `null` like [writeNull], and completes like
  /// [commit].
  Future<void> commitNull();

  /// Removes the value, under former keys too, so that a former value
  /// cannot resurface. A no-op, and no notification, when nothing is
  /// stored.
  void remove();

  /// Calls [listener] synchronously after a mutation that changed the
  /// stored state. Registering the same listener twice calls it twice.
  /// A listener added while the listeners are being notified is first
  /// called on the next change. See the class documentation for errors and
  /// for which mutations notify.
  void addListener(void Function() listener);

  /// Undoes one [addListener] of [listener]. A no-op when it is not
  /// registered. A listener removed while the listeners are being notified
  /// is not called again, not even by the notification under way.
  void removeListener(void Function() listener);

  /// Where this slot keeps the value: one key of a shared storage, or the
  /// slot itself. A setting registers there, so that two settings that
  /// read one place differently are rejected (see `SettingsRegistry`).
  SlotPlace get place;
}

/// Where a [SettingSlot] keeps its value, as the live settings over it
/// are told apart: one key of a shared storage ([KeyedSlotPlace]), or a
/// slot that holds one setting alone ([KeylessSlotPlace]).
@immutable
sealed class SlotPlace {
  const SlotPlace();
}

/// The key [key] of the shared [storage], and the [legacyKeys] it was
/// stored under before.
final class KeyedSlotPlace extends SlotPlace {
  /// The place [key] of [storage].
  const KeyedSlotPlace(this.storage, {required this.key, this.legacyKeys = const []});

  /// The storage the keys are on.
  final SettingsStorage storage;

  /// The key the value is stored under.
  final String key;

  /// Keys the value was stored under before [key], most recent first.
  final List<String> legacyKeys;
}

/// The slot [slot] itself, which holds one setting and has no key.
final class KeylessSlotPlace extends SlotPlace {
  /// The place that is [slot].
  const KeylessSlotPlace(this.slot);

  /// The slot.
  final SettingSlot<Object?> slot;
}
