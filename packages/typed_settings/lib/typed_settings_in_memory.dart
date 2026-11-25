/// The in-memory storage: a `SettingsStorage` that persists nothing.
///
/// For tests, widget previews and examples, and for settings that are
/// meant to be ephemeral (a demo mode, a guest session). Like the other
/// bundled and external storages it has its own library; import it next
/// to `package:typed_settings/typed_settings.dart`.
///
/// * `InMemoryStorage`: the shared box; `contents` is a copy of
///   its entries for assertions.
/// * `InMemorySettingSlot`: one value, with no key. A setting that does
///   not share a box takes it through its `inSlot` constructor.
///
/// An `InMemoryStorage` has a single key space; two of them are two
/// independent boxes.
library;

export 'src/slot/in_memory_setting_slot.dart';
export 'src/storage/in_memory_storage.dart';
