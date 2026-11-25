import 'package:meta/meta.dart';

/// Where the value a setting reads comes from. What the setting may skip,
/// report and tell its listeners follows from it alone.
@internal
enum ValueOrigin {
  /// Decoded from a raw value stored under the key.
  key,

  /// Decoded from a raw value still stored under a legacy key; the next
  /// write moves it to the key.
  legacyKey,

  /// The default: nothing is stored under the key and no legacy key holds
  /// anything, or the key holds an explicit `null` a non-nullable setting
  /// does not treat as a value.
  unset,

  /// The default, standing in for stored data the setting cannot use: data
  /// it failed to read, decode or validate, or an explicit `null` under a
  /// legacy key of a non-nullable setting.
  standIn;

  /// Whether the value is a usable stored value, under the key or a
  /// legacy key; see `Setting.hasStoredValue`.
  bool get isStored => this == key || this == legacyKey;
}

/// What a setting read: the [value] it exposes, its [origin] and the
/// [state] of the source it was derived from.
@internal
@immutable
final class SettingReading<T, S> {
  /// Creates the reading.
  const SettingReading(this.value, {required this.state, required this.origin});

  /// The value the setting exposes.
  final T value;

  /// What the source held for [value], compared with `==`: when it was
  /// read, or what the setting's own write of it leaves. A source that
  /// holds otherwise has changed since.
  final S state;

  /// Where [value] comes from.
  final ValueOrigin origin;
}

/// The reading of a setting, kept coherent with the source it reads.
///
/// Holds the last [SettingReading] until the source changes what the
/// setting would read, then drops it; the next [current] loads it again.
/// Tells the setting's listeners when the value, or whether or where it is
/// stored, changed, by any path: the setting's own mutation ([apply]), or
/// another one the source reports ([onSourceChanged]).
///
/// It knows the source only through its callbacks; the setting subscribes
/// [onSourceChanged] to the source, and [close]s the cache when it stops
/// following it.
@internal
final class SettingCache<T, S> {
  /// The cache of a setting, which [load] reads from the source,
  /// [readState] gives what the source holds now for, [equal] compares
  /// values of and [notify] tells the listeners of.
  SettingCache({
    required SettingReading<T, S> Function() load,
    required S Function() readState,
    required bool Function(T a, T b) equal,
    required void Function() notify,
  }) : _load = load,
       _readState = readState,
       _equal = equal,
       _notify = notify;

  final SettingReading<T, S> Function() _load;
  final S Function() _readState;
  final bool Function(T a, T b) _equal;
  final void Function() _notify;

  SettingReading<T, S>? _reading;

  /// How many of the setting's own mutations are running; the source's
  /// notifications of them are not external changes. A count, since a
  /// listener that the source notifies may mutate the setting again.
  int _ownMutations = 0;

  bool _closed = false;

  /// The reading, loaded when nothing is cached.
  SettingReading<T, S> get current => _reading ??= _load();

  /// Drops the reading without notifying, so that the next [current]
  /// loads it again.
  void invalidate() => _reading = null;

  /// Runs [mutation], a change of the source by the setting, with
  /// [expected] cached from the start: whoever the source notifies
  /// meanwhile reads the new value from the setting too, and the source's
  /// notifications of [mutation] are not taken for external changes.
  ///
  /// Once [mutation] returns, [expected] is still cached unless the source
  /// changed through another path meanwhile (a listener writing the key
  /// again): the source notifies every change synchronously, and
  /// [onSourceChanged] drops the reading for one that [expected] does not
  /// mirror. So the source is not read again here. The listeners are told
  /// when what the setting holds then differs from what it held before,
  /// unless the cache was closed meanwhile (a listener the source notified
  /// disposed the setting). An exception from [mutation] drops the
  /// reading, so that the next read sees what the source holds, and
  /// propagates without a notification.
  void apply(void Function() mutation, SettingReading<T, S> expected) {
    final previous = current;
    _reading = expected;
    _ownMutations++;
    try {
      mutation();
    } on Object {
      _reading = null;
      rethrow;
    } finally {
      _ownMutations--;
    }
    if (!_closed && _changedFrom(previous)) _notify();
  }

  /// The source's listener. A change through a path other than the
  /// setting's own (another setting over the same place, a migration,
  /// `clear()`) drops the reading and tells the listeners when what the
  /// setting holds changed.
  ///
  /// During a mutation of the setting's own ([apply]) the notification is
  /// either of that mutation, which the reading already mirrors, or of one
  /// made meanwhile by whoever the source notified; the latter drops the
  /// reading at once, so that nobody reads a value the source no longer
  /// holds, and [apply] tells the listeners when it returns.
  void onSourceChanged() {
    final previous = _reading;
    if (_closed || previous == null) return;
    if (_ownMutations > 0) {
      if (_readState() != previous.state) _reading = null;
      return;
    }
    _reading = null;
    if (_changedFrom(previous)) _notify();
  }

  /// Stops notifying: the setting no longer follows the source. A mutation
  /// under way still completes, without telling anyone.
  void close() => _closed = true;

  /// Whether what the setting now holds differs from [previous]: the
  /// value, whether it is stored under the key, or whether it is stored at
  /// all (`hasStoredValue`), a value under a legacy key included.
  bool _changedFrom(SettingReading<T, S> previous) {
    final now = current;
    return (now.origin == ValueOrigin.key) != (previous.origin == ValueOrigin.key) ||
        now.origin.isStored != previous.origin.isStored ||
        !_equal(now.value, previous.value);
  }
}
