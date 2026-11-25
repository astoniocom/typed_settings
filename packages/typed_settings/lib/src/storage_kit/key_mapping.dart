/// How the setting keys of a storage map onto the keys of the backend it
/// persists to, both ways: a storage that shares its backend with others
/// (a box among boxes) stores its keys apart from theirs and recognises
/// its own among everything the backend holds.
///
/// The two directions come together so that they cannot drift apart:
/// [settingKey] of [storedKey] of a key is that key, and [settingKey]
/// tells another storage's key apart by returning `null`.
abstract interface class KeyMapping {
  /// Every setting key stored as it is; the backend holds this storage's
  /// keys alone.
  static const KeyMapping identity = _IdentityKeyMapping();

  /// The key the backend holds the setting key [key] under.
  String storedKey(String key);

  /// The setting key the backend holds under [storedKey], or `null` when
  /// [storedKey] belongs to another storage.
  String? settingKey(String storedKey);
}

final class _IdentityKeyMapping implements KeyMapping {
  const _IdentityKeyMapping();

  @override
  String storedKey(String key) => key;

  @override
  String settingKey(String storedKey) => storedKey;
}
