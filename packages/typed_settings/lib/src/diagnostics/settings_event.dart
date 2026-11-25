import 'package:meta/meta.dart';
import 'package:typed_settings/src/diagnostics/stored_data.dart';
import 'package:typed_settings/src/foundation/build_mode.dart';
import 'package:typed_settings/src/validation/validation_errors.dart';

/// A diagnostic reported by a setting or a storage; see `SettingsObserver`.
///
/// Events describe situations the library recovers from on its own (a
/// stored value that cannot be used, a background write that failed), so
/// that they are visible rather than silent. Validation failures on write
/// are not events: they are thrown to the caller.
///
/// Every event carries the [key] it is about and what went wrong as
/// [error]: something thrown, or a rejection such as a failed validation.
/// [key] is null only for a setting or slot that has no key. Events
/// reported by a `SettingsStorage` always name a key.
/// Each concrete event narrows the type of [error] to what it actually
/// holds, so a sink that switches over the sealed hierarchy gets typed
/// access, while a generic sink reads [error] as an `Object`.
///
/// ## Stored data
///
/// An event may refer to the user's data: a raw stored value, the
/// rejected value of a validation error, the `source` of a
/// [FormatException]. That data can be a secret or personal data, so
/// [message] (and `toString`) leaves it out except in debug builds, and
/// [reportableError] is the error to hand to a crash reporter. The typed
/// fields keep the data for an observer that handles it deliberately;
/// [describe] chooses explicitly. An error thrown by a backend or a
/// listener is described as it is, except for the `source` of a
/// [FormatException]; an [Error] thrown while decoding stored data is
/// named by its type alone (see [DecodeFallbackEvent]).
@immutable
sealed class SettingsEvent {
  const SettingsEvent({
    required this.key,
    this.stackTrace,
  });

  /// Storage key the event is about, or null when the event is about a
  /// setting or slot that has no key.
  final String? key;

  /// Where [error] was thrown, when it was thrown at all.
  final StackTrace? stackTrace;

  /// What went wrong; see the concrete event for its type. It may hold
  /// stored data (see the class documentation); forward [reportableError]
  /// instead.
  Object get error;

  /// [error] as it may leave the device, for a crash reporter: outside
  /// debug builds, a [FormatException] without its `source`, and for a
  /// [DecodeFallbackEvent] an [Error] reduced to its type. A
  /// [ValidationError] already leaves the rejected value out of its
  /// `toString` there.
  Object get reportableError => isDebugBuild ? error : withoutStoredData(error);

  /// Human-readable one-line description; it includes the stored data the
  /// event refers to in debug builds only (see the class documentation).
  String get message => describe(includeData: isDebugBuild);

  /// The description of [message], with the stored data the event refers
  /// to only when [includeData] is set: for an observer that decides
  /// itself, such as one whose log never leaves the device.
  String describe({required bool includeData});

  @override
  String toString() => message;
}

/// A setting could not use its stored value and exposes its default
/// instead. The stored value is left untouched; the next explicit write
/// replaces it.
///
/// Either a [DecodeFallbackEvent] (the raw value could not be decoded) or
/// a [ValidationFallbackEvent] (the decoded value failed the invariant).
///
/// The event names the setting by [SettingsEvent.key] and does not hold
/// the setting: an observer that keeps events must not keep the setting
/// alive with them.
sealed class ReadFallbackEvent extends SettingsEvent {
  /// Creates the event for the setting stored under [key].
  const ReadFallbackEvent({required super.key, super.stackTrace});
}

/// The stored raw value could not be turned into a value of the setting:
/// decoding it, or checking or copying the decoded value, threw [error].
final class DecodeFallbackEvent extends ReadFallbackEvent {
  /// Creates the event for the setting stored under [key], whose stored
  /// value made [error] be thrown.
  const DecodeFallbackEvent({
    required super.key,
    required this.error,
    required StackTrace super.stackTrace,
  });

  /// What was thrown: an [Exception] for stored data the codec cannot use
  /// (see `SettingCodec`), or an [Error] for a bug the stored data exposed,
  /// such as a failed cast in a `fromJson`, which [stackTrace] leads to.
  /// Outside debug builds an [Error] other than a [TypeError] is named by
  /// its type alone in [message] and [reportableError], since its message
  /// may quote the data (the receiver of a [NoSuchMethodError], the value
  /// of an [ArgumentError]).
  @override
  final Object error;

  @override
  Object get reportableError => isDebugBuild ? error : decodeErrorWithoutStoredData(error);

  @override
  String describe({required bool includeData}) =>
      'Failed to decode ${_namedKey(key)}, using default: ${describeDecodeError(error, includeData: includeData)}';
}

/// The decoded stored value was rejected by the setting's invariant with
/// [error]. Nothing was thrown, so there is no stack trace.
final class ValidationFallbackEvent extends ReadFallbackEvent {
  /// Creates the event for the setting stored under [key], whose validator
  /// rejected the stored value for [error].
  const ValidationFallbackEvent({required super.key, required this.error});

  @override
  final ValidationError error;

  @override
  String describe({required bool includeData}) =>
      'Validation failed on read for ${_namedKey(key)}, using default: ${error.describe(includeData: includeData)}';
}

/// A storage holds a raw value under [key] that it cannot interpret as
/// the requested type; the key reads as absent.
final class StorageReadErrorEvent extends SettingsEvent {
  /// Creates the event; [error] says why [raw] could not be interpreted.
  const StorageReadErrorEvent({
    required super.key,
    required this.raw,
    required this.error,
    super.stackTrace,
  });

  /// The offending stored value, when available; [message] leaves it out
  /// except in debug builds.
  final Object? raw;

  /// Why [raw] could not be interpreted; whatever the backend reported,
  /// typically a [FormatException].
  @override
  final Object error;

  @override
  String describe({required bool includeData}) =>
      'Failed to read `$key` from storage${includeData ? ' ($raw)' : ''}: ${describeError(error, includeData: includeData)}';
}

/// A background write or removal failed after the in-memory state had
/// already been updated. The cache keeps the new value; the storage is
/// out of date until a later write of [key] is persisted, and until then
/// `SettingsStorage.flush` fails with a `SettingsPersistException` naming
/// it.
final class PersistErrorEvent extends SettingsEvent {
  /// Creates the event for the failed write or removal of [key].
  const PersistErrorEvent({
    required super.key,
    required this.error,
    required StackTrace super.stackTrace,
  });

  /// What the backend threw; an [Exception] or, for a bug, an [Error].
  @override
  final Object error;

  @override
  String describe({required bool includeData}) =>
      'Failed to persist `$key`: ${describeError(error, includeData: includeData)}';
}

/// A listener threw while being notified of a change. The change is
/// applied and the remaining listeners were still notified; the error is
/// a bug in the listener. [source] tells what the listener was
/// registered with.
final class ListenerErrorEvent extends SettingsEvent {
  /// Creates the event for the listener registered with [source] that
  /// threw [error] while being notified of a change of [key].
  const ListenerErrorEvent({
    required this.source,
    required super.key,
    required this.error,
    required StackTrace super.stackTrace,
  });

  /// What the listener was registered with.
  final ListenerSource source;

  /// What the listener threw; usually an [Error], since it is a bug.
  @override
  final Object error;

  @override
  String describe({required bool includeData}) {
    final listener = switch (source) {
      ListenerSource.storageKey => 'A listener of `$key`',
      ListenerSource.slot => 'A listener of the slot',
      ListenerSource.setting => key == null ? 'A listener of the setting' : 'A listener of setting `$key`',
    };
    return '$listener threw: ${describeError(error, includeData: includeData)}';
  }
}

/// What a listener of a [ListenerErrorEvent] was registered with.
enum ListenerSource {
  /// A key of a storage (`SettingsStorage.addKeyListener`); the event
  /// names the key.
  storageKey,

  /// A slot with no key (`SettingSlot.addListener`); the event names no
  /// key.
  slot,

  /// A setting (`ReadOnlySetting.addListener`); the event names its key,
  /// if it has one.
  setting,
}

/// [key] in backticks, or `the setting` when the event has no key.
String _namedKey(String? key) => key == null ? 'the setting' : '`$key`';
