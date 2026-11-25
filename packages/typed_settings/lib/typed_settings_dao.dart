/// A storage over a row-level DAO the application implements, typically a
/// database table with `(box, key, value)` columns.
///
/// This is the one persistent storage bundled with the core, because it
/// needs no dependency beyond the application's own database layer; the
/// other backends (`typed_settings_hive`, `typed_settings_shared_preferences`,
/// `typed_settings_secure_storage`) are separate packages, and
/// `typed_settings_drift` implements the DAO over a drift table. Import
/// it, like them, next to `package:typed_settings/typed_settings.dart`.
///
/// * `SettingsDao`: the four row operations to implement, plus an optional
///   transactional `writeBatch`.
/// * `CachedDaoStorage`: loads a box into memory through the DAO and
///   writes through in the background. It is a `StringBackedStorage`; see
///   `package:typed_settings/typed_settings_backend.dart` for that base.
library;

export 'src/storage/cached_dao_storage.dart';
export 'src/storage/settings_dao.dart';
