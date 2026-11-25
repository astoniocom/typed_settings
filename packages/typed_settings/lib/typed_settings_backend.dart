/// Building blocks for storage backends.
///
/// Import this library, next to `package:typed_settings/typed_settings.dart`,
/// when implementing a `SettingsStorage` over a new persistence mechanism.
/// Applications that only use settings need `typed_settings.dart` plus the
/// library of the storage they chose (`typed_settings_dao.dart`,
/// `typed_settings_in_memory.dart` or a backend package); a setting of a
/// new kind is built with `typed_settings_extend.dart`.
///
/// * `SettingsStorageBase`: what every backend shares (observer, key
///   listeners, read-error reporting, one open storage per `BackendBox`);
///   extend it and implement the typed getters and setters.
/// * `KeyChangeNotifier`: the key listener registry on its own, for a
///   storage implemented from the interface directly: the storage owns
///   one and forwards `addKeyListener` and `removeKeyListener` to it.
/// * `BackgroundPersistence`: write-behind queue with per-key ordering,
///   persist-error reporting and a `flush()` that fails for keys left
///   unpersisted, for backends whose in-memory state is updated
///   synchronously and persisted asynchronously. The storage owns one and
///   delegates `flush` to it; an operation is handed over with `persist`
///   or `track` and the `PersistTarget` it brings up to date.
/// * `KeyMapping`: how a storage's setting keys map onto the keys of a
///   backend it shares, both ways. `BoxKeySpace` is the mapping of one
///   box among several in a flat key space, escaped so that a dotted key
///   is never another box's.
/// * `StringBackedStorage`: a full scalar storage over a backend that can
///   only hold strings; implement `writeRaw`/`deleteRaw` and pass a
///   `KeyMapping` when the backend holds other storages' keys too.
/// * `decodeStoredScalar`: how a string-only backend records a scalar, so
///   an explicit null cannot be a stored string and an int is not a string.
///   SharedPreferences uses it for strings and explicit null only; its
///   other types are the platform's.
library;

export 'src/storage/settings_storage_base.dart';
export 'src/storage/string_backed_storage.dart';
export 'src/storage_kit/backend_box.dart' show BackendBox;
export 'src/storage_kit/background_persistence.dart';
export 'src/storage_kit/box_key_space.dart';
export 'src/storage_kit/key_change_notifier.dart';
export 'src/storage_kit/key_mapping.dart';
export 'src/storage_kit/scalar_string_encoding.dart';
