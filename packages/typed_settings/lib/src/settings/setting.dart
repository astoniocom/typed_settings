import 'package:listen/listen.dart';
import 'package:typed_settings/src/validation/exceptions.dart';
import 'package:typed_settings/src/validation/validation_errors.dart';

/// The read side of a setting: its current value, observable through
/// listeners or a stream.
///
/// Depend on this where a setting is only displayed or reacted to
/// (widgets that render a value, derived state, diagnostics). It cannot be
/// assigned or reset ([Setting] can) or disposed (only the owner that
/// created the setting can).
///
/// It is a [ValueListenable], so a `ValueListenableBuilder` and
/// `Listenable.merge` take the setting itself. The package stays free of
/// Flutter: `ValueListenable` comes from `package:listen`. Flutter 3.50
/// and later export that same type. An older Flutter declares a
/// `ValueListenable` of its own, which a setting does not implement.
abstract interface class ReadOnlySetting<T> implements ValueListenable<T> {
  /// Label for diagnostics, or null when the slot has nothing to name.
  ///
  /// A keyed slot supplies its key. A slot that exists only for this
  /// setting supplies null. The library uses it for diagnostics only, in
  /// release builds too: the messages of exceptions and the key of
  /// `SettingsEvent`s. Reads, writes, the registry and flush use the slot
  /// itself.
  String? get diagnosticKey;

  /// Value reported when nothing is stored or the stored value is unusable.
  T get defaultValue;

  /// Current value.
  ///
  /// Never throws because of stored data: a stored value that cannot be
  /// decoded or fails validation, a bug in the codec or the validator that
  /// it exposes included, is reported to the setting's `SettingsObserver`
  /// and replaced by [defaultValue]. Only an [Error] of the storage itself
  /// (a bug, or a use it rejects) propagates.
  @override
  T get value;

  /// Whether [value] equals [defaultValue].
  ///
  /// True both when nothing usable is stored and when the stored value
  /// equals [defaultValue]. [hasStoredValue] tells those apart.
  bool get isDefault;

  /// Whether a usable value is stored for this setting.
  ///
  /// True when that value equals [defaultValue], and for an explicit
  /// `null`. False when nothing is stored, and when the stored value is
  /// unusable so [value] stands in with [defaultValue]. Changing
  /// [defaultValue] in a later version changes what a setting with this
  /// `false` shows, and does not change one with this `true`.
  ///
  /// Assigning a value stores it, [defaultValue] included: an explicit
  /// choice of the value that happens to be the default is a choice, and
  /// stays when a later version changes the default. The exception is
  /// [defaultValue] over an unusable stored value, which leaves that value
  /// in place (see `Setting.value`). `reset` is what makes this `false`
  /// again.
  bool get hasStoredValue;

  /// Calls [listener] synchronously whenever [value] changes. Also when
  /// [value] stays the same but is no longer what the storage holds, or
  /// becomes so: a reset of a stored default, assigning the default while
  /// nothing is stored, assigning a value still stored under a former key. Not when nothing changes: assigning what
  /// is already stored, a reset of an already empty storage, a `clear()`
  /// that leaves this setting's value as it is. Registering the same
  /// listener twice calls it twice per change. A listener added while the
  /// listeners are being notified is first called on the next change.
  @override
  void addListener(VoidCallback listener);

  /// Undoes one [addListener] of [listener]; a no-op when it is not
  /// registered. A listener removed while the listeners are being notified
  /// (by another listener disposing what owns it) is not called again, not
  /// even by the notification under way.
  @override
  void removeListener(VoidCallback listener);

  /// A broadcast stream of [value].
  ///
  /// Each subscription emits the current [value] first, then whenever
  /// [addListener] would call. Events arrive asynchronously, after `listen`
  /// returns. Cancelling every subscription does not close the stream: a
  /// later `listen` on the same stream again starts with the current
  /// [value]. The stream closes when the setting is disposed. Subscribers
  /// must cancel their subscriptions.
  ///
  /// A `StreamBuilder` builds its first frame before that first event:
  /// Flutter delivers stream events asynchronously and builds the frame
  /// first. Pass the current [value] as its `initialData` for that frame
  /// to show the value.
  Stream<T> asStream();
}

/// A single typed, reactive application setting.
///
/// This is the contract for code that edits a setting: it adds
/// assignment, validation and reset to [ReadOnlySetting]. It cannot
/// dispose the setting: that is for the owner that created it, which
/// holds it as an `OwnedSetting`. How
/// and where the value is persisted, and whether it is cached, is an
/// implementation detail of the concrete setting class (see `StoredSetting`
/// for cache control).
///
/// Assigning [value] validates and persists, so it throws
/// [SettingValidationException] when the setting has a validator that
/// rejects the value. Code that assigns user input catches it (see
/// [validate] to check beforehand). Any other exception on assignment
/// means a value the setting cannot store at all (an enum constant outside
/// an `EnumSetting`'s `values`), which is a bug of the caller.
///
/// A setting is not a `ValueNotifier`. That contract promises a setter
/// that always succeeds, and assigning [value] throws
/// [SettingValidationException] when the validator rejects it. Reading and
/// listening need no adapter: the setting is the [ValueListenable]. An API
/// that edits a `ValueNotifier` takes the view from [asValueNotifier],
/// which decides what happens to a rejected value.
abstract interface class Setting<T> implements ReadOnlySetting<T> {
  /// Current value; see [ReadOnlySetting.value].
  @override
  T get value;

  /// Validates, persists and notifies listeners.
  ///
  /// Throws [SettingValidationException] when [validate] rejects the value;
  /// nothing is persisted or notified in that case. Assigning the value
  /// that is already stored is a no-op: nothing is written or notified.
  /// A current value that is not what the storage holds is written, so
  /// that the storage catches up: the default while nothing is stored
  /// (listeners are notified, since [hasStoredValue] changes), or a value
  /// still stored under a former key.
  ///
  /// The default that stands in for an unusable stored value is not
  /// written back, by the setter or by [commit]: that data may be readable
  /// by another release of the application (a newer one after a
  /// downgrade) or by a fixed codec, and a screen that writes back the
  /// value it shows must not destroy it. Another value replaces it, and
  /// [reset] removes it.
  ///
  /// The in-memory value and the listeners update in the call. The backend
  /// write follows. A storage created with a persistence delay holds that
  /// write and keeps only the latest value of the key, until the delay has
  /// passed without a newer write of it. [commit] and `SettingsStorage.flush`
  /// start a held write instead of waiting the delay out. Without a delay,
  /// every assignment is handed to the backend. Hive and shared preferences
  /// cannot merge writes already handed to them, so a control that changes
  /// continuously either uses that delay or assigns when the gesture ends
  /// (`onChangeEnd`) and shows the values in between from its own state.
  set value(T newValue);

  /// Assigns [newValue] like the [value] setter and completes once it is
  /// persisted, for a value that must not be lost unnoticed (a consent, a
  /// security switch).
  ///
  /// Validation, the in-memory update and the notification of listeners
  /// happen in the call itself, as for the setter; a value [validate]
  /// rejects fails the returned future with a [SettingValidationException]
  /// and changes nothing. Unlike the setter, the value that is already
  /// stored is written again (without a notification), so that a value
  /// whose earlier persistence failed is persisted again. The default over
  /// an unusable stored value is not written, as with the setter, and the
  /// future completes at once.
  ///
  /// The future completes once the value has reached the storage's backend
  /// and fails with a `SettingsPersistException` when it has not; a
  /// failure of another setting's key does not fail it. The value stays in
  /// memory either way, and the caller decides whether to retry, tell the
  /// user or assign another value.
  Future<void> commit(T newValue);

  /// Runs the checks the [value] setter applies, without writing anything.
  ///
  /// Returns `null` when [newValue] may be assigned, otherwise the error the
  /// setter would throw. Use it to validate user input before committing.
  ValidationError? validate(T newValue);

  /// Removes the stored value, so [value] returns [defaultValue].
  /// Listeners are notified when that is a change: [reset] of a value that
  /// is already absent is a no-op.
  void reset();

  /// A [ValueNotifier] view of this setting.
  ///
  /// The view forwards listeners to the setting and reads its value. It is
  /// cheap to create, including in a `build` method. `dispose` removes the
  /// listeners added through this view and does not dispose the setting;
  /// the setting's owner does that. `hasListeners` and `notifyListeners`
  /// apply to those listeners.
  ///
  /// Assigning a value the setting rejects calls [onValidationError] with
  /// the [SettingValidationException]; without a handler the exception
  /// propagates to the assigning code, as it does from the setting itself.
  /// Give the handler where the API that edits the view cannot catch it
  /// (a widget's `onChanged`).
  ///
  /// Two views are equal when they wrap the same setting and equal
  /// [onValidationError] functions, so a widget that is rebuilt with a
  /// fresh view does not resubscribe. A top-level or static function
  /// equals itself, and so does a method of one object. A handler written
  /// inline is a new function on every call, and the views are not equal.
  /// `editorView` of `typed_settings_flutter` compares the setting, the
  /// context and the label instead.
  ///
  /// A [StateError] when the setting has been disposed.
  ValueNotifier<T> asValueNotifier({SettingValidationErrorHandler? onValidationError});
}

/// Called by the view returned from [Setting.asValueNotifier] when the
/// setting rejects an assigned value.
typedef SettingValidationErrorHandler = void Function(SettingValidationException exception);
