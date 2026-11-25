/// The storage contract of `typed_settings` as an executable test suite.
///
/// A backend package adds this package as a dev dependency and calls
/// `storageConformance` from a test with a factory for its storage; the
/// suite checks the typed getter contract, explicit `null`, `remove`,
/// `clear`, `flush`, `reload` and the key listener contract, including
/// that every mutator updates the in-memory state synchronously. A
/// backend that something else can write to passes `writeOutside`, so
/// that `reload` is checked against a write made behind the storage.
///
/// `RecordingObserver` collects diagnostics for assertions in a backend's
/// own tests.
library;

export 'src/recording_observer.dart';
export 'src/storage_conformance.dart';
