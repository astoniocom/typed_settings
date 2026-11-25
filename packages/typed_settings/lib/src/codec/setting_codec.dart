/// Converts between a setting's value type [T] and the raw type [R] that a
/// slot holds: one of the types a `SettingsStorage` stores, for a keyed
/// slot.
///
/// A codec is pure: it knows nothing about keys, storages or defaults.
/// [decode] must throw an [Exception] (typically a [FormatException]) when
/// [R] cannot be turned into a valid [T]; the setting reports the error and
/// falls back to its default value. An [Error] escaping [decode] (a failed
/// cast, a [RangeError] from a core constructor) is reported and replaced
/// by the default too, since stored data must not make a read throw, but
/// as a bug, whose message diagnostics leave out outside debug builds: so
/// convert such cases into a [FormatException] that says what is wrong.
/// Put the data that could not be decoded into the exception's `source`,
/// not its message: diagnostics show the source in debug builds only, so
/// stored values stay out of the logs and crash reports of a shipped app.
/// [encode] must throw when [T] cannot be represented, which makes the
/// assignment fail before anything is cached or notified.
abstract interface class SettingCodec<T, R> {
  /// Converts a raw stored value into the setting's value type.
  T decode(R raw);

  /// Converts a value into the representation to store.
  R encode(T value);
}

/// Codec for values stored as they are (`bool`, `int`, `double`, `String`).
final class IdentityCodec<T> implements SettingCodec<T, T> {
  /// Creates the codec; stateless, so prefer the `const` form.
  const IdentityCodec();

  @override
  T decode(T raw) => raw;

  @override
  T encode(T value) => value;
}
