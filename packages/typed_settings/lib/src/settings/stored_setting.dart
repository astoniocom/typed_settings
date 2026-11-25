import 'package:listen/listen.dart';
import 'package:meta/meta.dart';
import 'package:typed_settings/src/codec/setting_codec.dart';
import 'package:typed_settings/src/diagnostics/settings_event.dart';
import 'package:typed_settings/src/settings/internal/setting_cache.dart';
import 'package:typed_settings/src/settings/internal/setting_notifier.dart';
import 'package:typed_settings/src/settings/owned_setting.dart';
import 'package:typed_settings/src/settings/setting.dart';
import 'package:typed_settings/src/settings/setting_view_listeners.dart';
import 'package:typed_settings/src/settings/settings_registry.dart';
import 'package:typed_settings/src/slot/keyed_setting_slot.dart';
import 'package:typed_settings/src/slot/setting_slot.dart';
import 'package:typed_settings/src/slot/slot_state.dart';
import 'package:typed_settings/src/storage/settings_storage.dart';
import 'package:typed_settings/src/validation/exceptions.dart';
import 'package:typed_settings/src/validation/setting_validator.dart';
import 'package:typed_settings/src/validation/validation_errors.dart';

/// A [Setting] backed by a [SettingSlot].
///
/// Assembled from strategies: a [slot] that reads and writes one raw
/// value of type [R], a [codec] that converts between [R] and the value
/// type [T], an [_equality] and a [_snapshot]. What is left here is the
/// cache, validation, coherence with the slot and the lifecycle; the
/// listeners and the stream are kept by a notifier the setting owns. The
/// built-in setting classes
/// (`IntSetting`, `ColorSetting`, ...) are presets of these strategies
/// and add nothing else; a custom value type needs only a [SettingCodec],
/// a nullable one a slot that presents an explicit `null` as a value
/// (see `StoredNullableSetting`).
///
/// Consumers should depend on [Setting] (or [ReadOnlySetting] when they
/// only read) rather than on this class: [R] describes how the value is
/// stored, not what the setting is.
///
/// ## Writing a preset
///
/// A preset is a subclass with constructors and nothing else: it fixes
/// the strategies for one value type and forwards the remaining options
/// of this class unchanged. Dart does not forward constructor parameters
/// by itself, so each preset lists them, and an option added here has to
/// be added to every preset by hand.
///
/// Its default constructor takes a `storage`, a `key` and `legacyKeys`,
/// so that a caller names where the value lives and not how it is
/// stored: the raw type [R] stays inside the preset, and a preset can
/// change it without changing a caller. The constructor binds the key
/// with the [KeyedSettingSlot] of [R] (`KeyedSettingSlot.ofInt` for an
/// `int`) and redirects to `inSlot`.
///
/// `inSlot` takes a [SettingSlot] of [R] for a store that holds this
/// setting alone and has no key, and is where the strategies are fixed.
/// A preset adds fields only for what callers need to know about the
/// value type (`EnumSetting.values`); it does not override behaviour.
/// The nullable variant is the same preset over `StoredNullableSetting`,
/// with `defaultValue` optional.
///
/// The language holds presets to this: this class is `base`, so a preset
/// is a `base` (or `final`) subclass and nothing implements the class
/// around its invariants, and the behaviour is `@nonVirtual`, so the
/// analyzer reports an override. A preset may build on another preset
/// the same way, as `JsonSchemaMapSetting` does on `MapSetting`.
///
/// ```dart
/// base class DurationSetting extends StoredSetting<Duration, int> {
///   DurationSetting({
///     required SettingsStorage storage,
///     required String key,
///     required Duration defaultValue,
///     List<String> legacyKeys = const [],
///     SettingValidator<Duration>? validator,
///   }) : this.inSlot(
///           KeyedSettingSlot.ofInt(storage, key: key, legacyKeys: legacyKeys),
///           defaultValue: defaultValue,
///           validator: validator,
///         );
///
///   DurationSetting.inSlot(
///     SettingSlot<int> slot, {
///     required super.defaultValue,
///     super.validator,
///   }) : super(slot: slot, codec: const DurationMillisCodec());
/// }
///
/// final timeout = DurationSetting(
///   storage: preferences,
///   key: 'timeout',
///   defaultValue: Duration.zero,
/// );
/// ```
///
/// A value type used once needs no preset: this class takes the slot and
/// the codec directly (`StoredSetting(slot: KeyedSettingSlot.ofString(storage,
/// key: 'point'), codec: const PointCodec(), ...)`); the codec is what
/// fixes the raw type there.
///
/// Behaviour that a preset seems to need belongs in a strategy: a new
/// representation is a [SettingCodec], a type a storage holds in addition
/// to the four a [KeyedSettingSlot] over its getter and setter (see the
/// unnamed constructor there), a new notion of "same value" an [_equality], a defensive copy
/// a [_snapshot]. Put a validator a preset always applies into
/// `validator` (see `JsonSchemaMapSetting`), not into a subclass of this
/// class.
///
/// The cached value stays coherent with the slot: the setting listens
/// for changes on [slot] and re-reads when another instance, a
/// migration or `clear()` changes what it would read, and tells its
/// listeners when that changes [value] or whether [value] is stored. A
/// keyed slot listens for its key and its legacy keys, so a change of
/// either is such a change. Its own write is cached before the slot
/// notifies anyone, so whoever the slot notifies reads the new value
/// from this setting as well; a change made in response (a listener
/// writing the value again) is picked up as soon as the write returns,
/// and listeners are told when [value] or its origin changed. The
/// listeners are removed in [dispose]; the owner that created the
/// setting must dispose it. Until then the slot holds a reference to
/// the setting, so a setting that is created per screen and never
/// disposed lives, and keeps being notified, for as long as the slot
/// does. After [dispose], every operation throws a [StateError].
///
/// Creating a setting does not touch the stored data: the setting
/// registers at its slot's place ([SettingSlot.place], see
/// [SettingsRegistry]) and registers its listener on the slot.
/// Reads never write either; the slot is written by the [value]
/// setter, [commit] and [reset] alone.
///
/// ## Values as stored
///
/// A value enters the setting as the slot would give it back: [codec]
/// encodes and decodes it, and [_snapshot] copies it, before it is
/// validated, compared, cached or exposed, [defaultValue] included. A
/// codec that drops something (the time zone and the microseconds of a
/// `DateTime` through `DateTimeMillisCodec`) therefore drops it at once,
/// so [value] is the same before and after a restart, and so are `==` and
/// [isDefault]. A value whose encoding the codec cannot decode is rejected
/// with the codec's exception when it is assigned.
base class StoredSetting<T, R> implements OwnedSetting<T> {
  /// Assembles a setting over [slot]; see the fields for each strategy.
  /// [defaultValue] must survive [codec] and pass the validator's
  /// invariant; an [ArgumentError] reports it. A [StateError] reports a
  /// conflict with a live setting over the same place (another type for
  /// the same slot, or, for a keyed slot, overlapping keys), or a
  /// closed storage. Nothing stays registered when the constructor throws.
  ///
  /// Every field is assigned in the body. An initializer that reads a
  /// parameter makes dart2js 3.14 crash while it inlines this constructor
  /// through a preset's redirecting `this.inSlot` (`HInvokeStatic` is not
  /// a subtype of `HLocalValue`).
  StoredSetting({
    required T defaultValue,
    required SettingCodec<T, R> codec,
    required SettingSlot<R> slot,
    bool Function(T a, T b)? equality,
    T Function(T value)? snapshot,
    SettingValidator<T>? validator,
  }) {
    this.codec = codec;
    this.validator = validator;
    _slot = slot;
    _snapshot = snapshot ?? _identity<T>;
    this.defaultValue = _storedDefault(codec, _snapshot, defaultValue);
    _equality = equality ?? _operatorEquals;
    final error = validator?.validateRead(this.defaultValue);
    if (error != null) {
      throw ArgumentError.value(
        this.defaultValue,
        'defaultValue',
        'fails validation for ${_settingName(diagnosticKey)}: $error',
      );
    }
    SettingsRegistry.register(this, slot.place, shape: (value: T, raw: R, codec: codecType));
    try {
      slot.addListener(_cache.onSourceChanged);
    } on Object {
      SettingsRegistry.unregister(this, slot.place);
      rethrow;
    }
  }

  /// Where [value] is persisted. Keyed or not, it is one value.
  late final SettingSlot<R> _slot;

  /// The type of the codec that turns raw values into [T], which the
  /// registry compares between settings over one place. A codec that only
  /// wraps another names the wrapped one (see `StoredNullableSetting`).
  @internal
  Type get codecType => codec.runtimeType;

  static bool _operatorEquals(Object? a, Object? b) => a == b;

  static T _identity<T>(T value) => value;

  /// [defaultValue] as the slot would give it back; an [ArgumentError]
  /// when [codec] cannot decode its encoding.
  static T _storedDefault<T, R>(SettingCodec<T, R> codec, T Function(T value) snapshot, T defaultValue) {
    try {
      return snapshot(codec.decode(codec.encode(defaultValue)));
    } on Exception catch (error) {
      throw ArgumentError.value(defaultValue, 'defaultValue', 'does not survive its codec: $error');
    }
  }

  /// [value] as the slot would give it back, with the raw form that is
  /// written for it; see the class documentation. [value] is encoded as
  /// it is: encoding runs synchronously, so the caller cannot change it
  /// meanwhile, and only the decoded value is kept.
  ({T value, R raw}) _asStored(T value) {
    final raw = codec.encode(value);
    return (value: _snapshot(codec.decode(raw)), raw: raw);
  }

  /// The key of the slot's place, for messages only; `null` for a slot
  /// with no key. See [ReadOnlySetting.diagnosticKey].
  @nonVirtual
  @override
  String? get diagnosticKey => switch (_slot.place) {
    KeyedSlotPlace(:final key) => key,
    KeylessSlotPlace() => null,
  };

  /// The value given to the constructor, as the slot would give it
  /// back (see the class documentation).
  @nonVirtual
  @override
  late final T defaultValue;

  /// Converts between [T] and the raw type [R] stored by [slot].
  @nonVirtual
  late final SettingCodec<T, R> codec;

  /// Equality used by [isDefault] and by the [value] setter to skip writes
  /// of an unchanged value. `==` unless given; collection-valued settings
  /// pass a structural comparison.
  @nonVirtual
  late final bool Function(T a, T b) _equality;

  /// Produces the instance that is cached, exposed through [value] and
  /// handed to the slot: for mutable types, a defensive (preferably
  /// unmodifiable) copy, so that neither the caller's object nor a
  /// slot's internal state can alias the setting's value. Applied to
  /// decoded values, assigned values and [defaultValue] alike. Identity
  /// unless given.
  @nonVirtual
  late final T Function(T value) _snapshot;

  /// Validation policy; see [SettingValidator] for when each check applies.
  @nonVirtual
  late final SettingValidator<T>? validator;

  /// Where the value is persisted. A [KeyedSettingSlot] is one key of a
  /// shared box; any other [SettingSlot] holds this setting alone.
  @nonVirtual
  SettingSlot<R> get slot => _slot;

  /// What this setting read from [slot], kept coherent with it; the
  /// mutations below go through it so that listeners are told of them.
  /// Subscribed to [slot] for as long as the setting lives.
  late final SettingCache<T, SlotState<R>?> _cache = SettingCache(
    load: _load,
    readState: _slot.read,
    equal: _equality,
    notify: _notifier.notify,
  );

  /// The listeners of this setting and its stream.
  late final SettingNotifier<T> _notifier = SettingNotifier(
    read: () => value,
    onListenerError: (error, stackTrace) => _slot.observer.report(
      ListenerErrorEvent(source: ListenerSource.setting, key: diagnosticKey, error: error, stackTrace: stackTrace),
    ),
  );

  bool _disposed = false;

  /// Throws a [StateError] once the setting has been disposed; [operation]
  /// names what was attempted. Every operation calls it first, in every
  /// build mode: a disposed setting no longer follows the slot, so a read
  /// would return a stale value and a write could be skipped as a no-op
  /// against it.
  void _checkNotDisposed(String operation) {
    if (_disposed) throw StateError(_disposedMessage(operation));
  }

  String _disposedMessage(String operation) =>
      diagnosticKey == null ? '$operation on a disposed setting' : '$operation on a disposed setting `$diagnosticKey`';

  @nonVirtual
  @override
  void addListener(void Function() listener) {
    _checkNotDisposed('addListener');
    _notifier.add(listener);
  }

  @nonVirtual
  @override
  void removeListener(void Function() listener) => _notifier.remove(listener);

  @nonVirtual
  @override
  Stream<T> asStream() {
    _checkNotDisposed('asStream');
    return _notifier.asStream();
  }

  /// The reading [value] written as [raw] under the key leaves.
  _Reading<T, R> _written(T value, R raw) =>
      SettingReading(value, state: RawSlotState<R>(raw), origin: ValueOrigin.key);

  @nonVirtual
  @override
  T get value {
    _checkNotDisposed('value');
    return _cache.current.value;
  }

  /// Reads [slot] (the key, or the legacy key standing in for it) and
  /// turns a failure into a default standing in for the stored data.
  /// Never writes.
  ///
  /// Stored data comes from outside the app, so whatever turning it into
  /// a value throws is reported, a bug in the codec, the invariant or the
  /// snapshot included: one stored value that exposes such a bug must not
  /// make every read throw, on every start. The storage reports a value it
  /// cannot interpret instead of throwing (see [SettingsStorage]); an
  /// exception it throws anyway is reported like unusable data, while an
  /// [Error] from it is a bug in the storage or in its use, which a
  /// default would hide, and propagates.
  _Reading<T, R> _load() {
    final SlotState<R> found;
    try {
      found = _slot.read();
    } on Exception catch (error, stackTrace) {
      return _fallBack(DecodeFallbackEvent(key: diagnosticKey, error: error, stackTrace: stackTrace), null);
    }
    switch (found) {
      case AbsentSlotState() || NullSlotState(fromLegacyKey: false):
        return SettingReading(_snapshot(defaultValue), state: found, origin: ValueOrigin.unset);
      case NullSlotState(fromLegacyKey: true):
        // Only the slot of a `StoredNullableSetting` turns an explicit null
        // into a value; to this setting it is not one, and the next write
        // replaces it.
        return SettingReading(_snapshot(defaultValue), state: found, origin: ValueOrigin.standIn);
      case RawSlotState(:final raw, :final fromLegacyKey):
        try {
          return SettingReading(
            _snapshot(_validateRead(codec.decode(raw))),
            state: found,
            origin: fromLegacyKey ? ValueOrigin.legacyKey : ValueOrigin.key,
          );
        } on _ReadRejected catch (rejected) {
          return _fallBack(ValidationFallbackEvent(key: diagnosticKey, error: rejected.error), found);
        } on Object catch (error, stackTrace) {
          return _fallBack(DecodeFallbackEvent(key: diagnosticKey, error: error, stackTrace: stackTrace), found);
        }
    }
  }

  /// Reports [event] and reads the default in place of the unusable stored
  /// data found in [state], so that the failing read is not repeated on
  /// every access; see [ValueOrigin.standIn].
  _Reading<T, R> _fallBack(ReadFallbackEvent event, SlotState<R>? state) {
    _slot.observer.report(event);
    return SettingReading(_snapshot(defaultValue), state: state, origin: ValueOrigin.standIn);
  }

  /// [loaded], or a [_ReadRejected] when the validator's invariant
  /// rejects it.

  T _validateRead(T loaded) {
    final error = validator?.validateRead(loaded);
    if (error != null) throw _ReadRejected(error);
    return loaded;
  }

  /// Whether assigning a value equal to the current one, read from
  /// [origin], leaves the slot as it is: the slot holds that value under
  /// the key already, or holds data this setting cannot use. The latter
  /// may be readable by another release (a newer one after a downgrade)
  /// or a fixed codec, and a screen that shows the default and writes it
  /// back must not destroy it; another value or a reset replaces it. Any
  /// other origin has something to store: a legacy key must be moved to
  /// the key, and a default that nothing stores is assigned like any
  /// other value, so that the choice is stored.
  static bool _keepsEqualWrite(ValueOrigin origin) => origin == ValueOrigin.key || origin == ValueOrigin.standIn;

  @nonVirtual
  @override
  set value(T newValue) {
    _checkNotDisposed('value=');
    // Compare against the current value even on a cold setting, so that
    // assigning what is already stored is a no-op regardless of cache
    // state (see [_keepsEqualWrite]). The value as given is compared
    // first, so that assigning the current value again costs no encoding;
    // a different one may still equal it once stored (a codec that drops
    // something).
    final current = _cache.current;
    if (_keepsEqualWrite(current.origin) && _equality(newValue, current.value)) return;
    final stored = _asStored(newValue);
    if (_keepsEqualWrite(current.origin) && _equality(stored.value, current.value)) return;

    final error = validator?.validateWrite(stored.value);
    if (error != null) throw SettingValidationException(diagnosticKey, error);

    _cache.apply(() => _slot.write(stored.raw), _written(stored.value, stored.raw));
  }

  /// Applies [newValue] like the [value] setter, except that an equal value
  /// is written too, then waits for [slot] to persist it; see
  /// [Setting.commit] and [SettingSlot.commit]. The default over unusable
  /// stored data is not written, as with the setter: the data stays and
  /// keeps reading as that default.
  @nonVirtual
  @override
  Future<void> commit(T newValue) async {
    _checkNotDisposed('commit');
    final stored = _asStored(newValue);
    final error = validator?.validateWrite(stored.value);
    if (error != null) throw SettingValidationException(diagnosticKey, error);

    final current = _cache.current;
    if (current.origin == ValueOrigin.standIn && _equality(stored.value, current.value)) return;
    final unchanged = current.origin == ValueOrigin.key && _equality(stored.value, current.value);
    final (committed, raw) = unchanged ? (current.value, codec.encode(current.value)) : (stored.value, stored.raw);
    late final Future<void> persisted;
    _cache.apply(() => persisted = _slot.commit(raw), _written(committed, raw));
    await persisted;
  }

  /// Checks [newValue] as the slot would give it back, as the setter
  /// does; an exception of [codec] for a value it cannot encode, or whose
  /// encoding it cannot decode, propagates.
  @nonVirtual
  @override
  ValidationError? validate(T newValue) {
    _checkNotDisposed('validate');
    final stored = _asStored(newValue).value;
    return validator?.validateWrite(stored);
  }

  /// Drops the cached value without touching the stored one.
  ///
  /// The next read fetches from [slot] again. Does not notify listeners.
  /// Changes made through the slot (another instance over the same key,
  /// a migration, `clear()`, a `SettingsStorage.reload`) are picked up
  /// automatically; this is for a slot that changes without notifying,
  /// such as one of your own whose store is written elsewhere.
  ///
  /// It does not go back to a storage's backend: a storage reads from the
  /// state it holds in memory, so after another isolate or native code
  /// wrote to the backend this reads the same value again. Call
  /// `SettingsStorage.reload` for that; it loads the backend and notifies
  /// the settings itself. Not part of [Setting]: consumers of a setting
  /// have no business with its cache.
  @nonVirtual
  void invalidate() {
    _checkNotDisposed('invalidate');
    _cache.invalidate();
  }

  /// Removes the stored value from [slot] (see [SettingSlot.remove]).
  @nonVirtual
  @override
  void reset() {
    _checkNotDisposed('reset');
    _cache.apply(
      _slot.remove,
      SettingReading(_snapshot(defaultValue), state: AbsentSlotState<R>(), origin: ValueOrigin.unset),
    );
  }

  /// Unregisters from the slot and drops the listeners. Every other
  /// operation of the setting throws a [StateError] afterwards, so that
  /// use after disposal surfaces where it happens. Disposing again is a
  /// harmless bug: it fails in debug mode and does nothing otherwise.
  @nonVirtual
  @override
  void dispose() {
    assert(!_disposed, _disposedMessage('dispose'));
    if (_disposed) return;
    SettingsRegistry.unregister(this, _slot.place);
    _slot.removeListener(_cache.onSourceChanged);
    _cache.close();
    _disposed = true;
    _notifier.close();
  }

  @nonVirtual
  @override
  bool get isDefault => _equality(value, defaultValue);

  /// A usable value in the slot, under its current key or a legacy key
  /// (see [ValueOrigin.isStored]). An absent key, an explicit `null` a
  /// non-nullable setting does not treat as a value, and stored data
  /// [value] had to replace with [defaultValue] are not one.
  @nonVirtual
  @override
  bool get hasStoredValue {
    _checkNotDisposed('hasStoredValue');
    return _cache.current.origin.isStored;
  }

  @nonVirtual
  @override
  ValueNotifier<T> asValueNotifier({SettingValidationErrorHandler? onValidationError}) {
    _checkNotDisposed('asValueNotifier');
    return _SettingValueNotifier<T>(this, onValidationError);
  }
}

/// What a setting over a slot of [R] read: the source state is what the
/// slot read, or `null` when the slot could not be read.
typedef _Reading<T, R> = SettingReading<T, SlotState<R>?>;

/// [label] in backticks, or `the setting` when the slot has no key.
String _settingName(String? label) => label == null ? 'the setting' : '`$label`';

/// Thrown by `StoredSetting._validateRead` for a stored value the read
/// check rejects; caught by the value getter, never seen by callers.
class _ReadRejected implements Exception {
  const _ReadRejected(this.error);

  final ValidationError error;
}

/// Forwards to the setting and keeps the listeners it registered there;
/// see [Setting.asValueNotifier].
///
/// Equality is the setting and the error handler. The listener list is not
/// part of it, so a rebuilt widget can keep the view it already subscribed.
/// The handler is compared with `==`: two tear-offs of one method are equal
/// and not identical.
@immutable
class _SettingValueNotifier<T> implements ValueNotifier<T> {
  _SettingValueNotifier(this._setting, this._onValidationError);

  final Setting<T> _setting;
  final SettingValidationErrorHandler? _onValidationError;
  final SettingViewListeners _listeners = SettingViewListeners();

  @override
  T get value => _setting.value;

  @override
  set value(T newValue) {
    _listeners.checkUsable('value=');
    try {
      _setting.value = newValue;
    } on SettingValidationException catch (exception) {
      final handler = _onValidationError;
      if (handler == null) rethrow;
      handler(exception);
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(_setting, listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(_setting, listener);

  @override
  void dispose() => _listeners.dispose(_setting);

  @override
  void notifyListeners() => _listeners.notify();

  @override
  bool get hasListeners => _listeners.hasListeners;

  @override
  bool operator ==(Object other) =>
      other is _SettingValueNotifier<T> &&
      identical(other._setting, _setting) &&
      other._onValidationError == _onValidationError;

  @override
  int get hashCode => Object.hash(identityHashCode(_setting), _onValidationError);

  @override
  String toString() => '$_setting view';
}
