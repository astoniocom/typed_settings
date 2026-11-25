import 'package:typed_settings/src/diagnostics/settings_observer.dart';
import 'package:typed_settings/src/diagnostics/settings_persist_exception.dart';

/// Key-value persistence for settings.
///
/// A key is in one of three states: absent, holding a typed value (a
/// `bool`, `int`, `double` or `String`, see [getInt] and the other typed
/// getters), or holding an explicit `null` ([setNull]). Nullable settings
/// rely on the third state to persist "the user chose nothing" distinctly
/// from "nothing stored yet", which reads as the setting's default.
/// Structured values (maps, lists, custom types) are encoded by their
/// setting's codec into one of the four types, typically a JSON string.
///
/// This is the pure contract, so it can be implemented directly (a
/// decorator, a mock). Backends extend `SettingsStorageBase` (in
/// `package:typed_settings/typed_settings_backend.dart`), which implements
/// the observer, the key listeners and the lifecycle.
///
/// ## Typed getter contract
///
/// Every typed getter (`getInt`, `getString`, ...) follows the same rules,
/// whatever the backend:
///
/// * an absent key and an explicit `null` read as `null`;
/// * a present value that cannot be interpreted as the requested type (a
///   string under an int key, an unparsable string in a string-backed
///   backend) is reported to [observer] as a `StorageReadErrorEvent` and
///   reads as `null`, as if absent;
/// * a typed getter never throws because of stored data.
///
/// Settings therefore see the same thing on every backend: the key is
/// absent and the default applies. Decoding failures of the setting's own
/// codec are a separate, setting-level concern (`ReadFallbackEvent`).
///
/// ## Mutation contract
///
/// Every mutator (the typed setters, [setNull], [remove], [clear]) updates
/// the in-memory state synchronously and then notifies the listeners of
/// the key (of every key, from [clear]) before returning. Settings
/// register through [addKeyListener] and drop their cache on
/// notification, so several setting instances over one key, migrations
/// and `clear()` all stay coherent without manual invalidation. The
/// storage conformance test checks this for every backend.
///
/// ## Loading
///
/// Reads are synchronous, so a storage holds its data in memory: the
/// asynchronous factory of a backend (`CachedDaoStorage.create`,
/// `HiveStorage.create`, ...) loads it, and the future it returns is the
/// signal that the storage is ready. Settings are created over a loaded
/// storage and read the stored values from the first read, never a
/// default standing in for data still on its way.
///
/// What a factory loads, and so what it costs, depends on the backend and
/// is documented there: one box, or more than that. Keep the path to the
/// first frame short: split settings into boxes by when they are needed,
/// create before `runApp` only the storages the first screen reads,
/// create the others when their feature opens, and create independent
/// storages concurrently rather than one after another.
///
/// ## Lifecycle
///
/// A storage serves one box of one backend (a database table, the shared
/// preferences, a Hive box), and one open storage at a time may serve
/// it: creating a second one over the same backend and box throws a
/// [StateError]. Each storage keeps its own key listeners, and some their
/// own copy of the data, so settings over two storages of one box would
/// not see each other's writes. Create the storage once, where the
/// application is put together, and hand it to the code that needs it.
///
/// [close] releases the box: another storage may then be created over it,
/// which loads the backend anew (a test does so to simulate a restart).
/// Every read and write of a closed storage throws a [StateError], and so
/// does every operation of a setting over it; dispose those settings
/// first.
abstract interface class SettingsStorage {
  /// The observer this storage reports its diagnostics to, and the one
  /// every setting backed by this storage reports to. Fixed when the
  /// storage is created; a storage created
  /// without one uses a [DefaultSettingsObserver].
  SettingsObserver get observer;

  /// Calls [listener] synchronously whenever this storage changes [key]
  /// through one of its mutators; see the mutation contract in the class
  /// documentation. Changes made to the backend behind the storage's back
  /// (another isolate, native code) are observed once [reload] has loaded
  /// them, not before.
  ///
  /// A listener that throws does not disturb the mutation or the other
  /// listeners of the key: the error is reported to [observer] as a
  /// `ListenerErrorEvent` and notification continues. A listener added
  /// while the listeners of [key] are being notified is first called on
  /// the next change. A listener registered twice is called twice.
  void addKeyListener(String key, void Function() listener);

  /// Undoes one [addKeyListener] of [listener]; a no-op when it is not
  /// registered. A listener removed while the listeners of [key] are being
  /// notified (by another listener disposing what owns it) is not called
  /// again, not even by the notification under way.
  void removeKeyListener(String key, void Function() listener);

  /// The `bool` under [key], or `null`; see the typed getter contract.
  bool? getBool(String key);

  /// Stores [value] under [key], replacing any previous state of the key.
  void setBool(String key, bool value);

  /// The `int` under [key], or `null`; see the typed getter contract.
  int? getInt(String key);

  /// Stores [value] under [key], replacing any previous state of the key.
  void setInt(String key, int value);

  /// The `double` under [key], or `null`; see the typed getter contract.
  double? getDouble(String key);

  /// Stores [value] under [key], replacing any previous state of the key.
  void setDouble(String key, double value);

  /// The `String` under [key], or `null`; see the typed getter contract.
  String? getString(String key);

  /// Stores [value] under [key], replacing any previous state of the key.
  void setString(String key, String value);

  /// Removes [key] entirely, whether it holds a typed value or an explicit
  /// `null`.
  void remove(String key);

  /// Stores an explicit `null` under [key], replacing any typed value.
  ///
  /// Afterwards [hasNull] is `true` and every typed getter returns `null`
  /// for [key].
  void setNull(String key);

  /// Whether [key] holds an explicit `null` written by [setNull].
  ///
  /// `false` both for absent keys and for keys holding a typed value.
  bool hasNull(String key);

  /// Keys that hold a value or an explicit `null`, in this storage's own
  /// key space. Absent keys are not included.
  ///
  /// A snapshot: a later mutation of this storage does not change it, so a
  /// caller may remove keys while iterating it.
  Iterable<String> get keys;

  /// Removes every key of this storage (for a box-scoped backend, of its
  /// box only).
  ///
  /// A mutator like the others: the in-memory state is cleared and every
  /// key's listeners are notified synchronously, before this method
  /// returns, so settings read their default right away. The returned
  /// future completes when the removal has been persisted; it includes a
  /// [flush] and fails like one. A write issued after `clear` is not wiped
  /// by it.
  Future<void> clear();

  /// Completes when all persistence operations started so far have
  /// finished, and fails if one of them left a key unpersisted.
  ///
  /// Writes update the in-memory state synchronously and persist in the
  /// background; await this before the application may be terminated (or
  /// after several writes) to make sure nothing is lost. Only the
  /// operations issued before the call are waited for: a key that keeps
  /// being written (a slider bound to a setting) cannot keep the future
  /// from completing. A storage created with a persistence delay has not
  /// handed a held single-key write to the backend yet. This call starts
  /// those writes instead of waiting the delay out, then waits for them
  /// as for any other write issued before the call.
  ///
  /// A key whose persistence failed is out of date until a later operation
  /// persists it: a successful write or removal of the key, or a bulk
  /// operation that covers it (such as a `clear` that empties the whole
  /// box). When a key is out of date because of an operation issued
  /// before the call, the future completes with a
  /// [SettingsPersistException] naming it, also if that operation failed
  /// long before the call. Each failure has been reported to [observer] as
  /// a `PersistErrorEvent` when it happened, so a caller with nothing to
  /// add (a flush when the application is paused) may ignore the
  /// exception. A storage that persists nothing never fails.
  ///
  /// With [keys], the future waits only for the operations issued before
  /// the call over one of those keys or over every key (a `clear`), and
  /// only those keys can make it fail: a caller that needs one value
  /// persisted is neither held back nor failed by another. Code that must
  /// know everything has persisted (before the application may be
  /// terminated) calls this without [keys]. After a bulk
  /// operation over every key that did not persist (a failed `clear`),
  /// each of [keys] counts as out of date until it is persisted again,
  /// since the backend may still hold its old state.
  Future<void> flush({Iterable<String>? keys});

  /// Loads what the backend holds now and makes it the in-memory state:
  /// for a backend that something other than this storage may write to
  /// (another isolate, such as a push handler or a background task, an
  /// app extension, native code). Nothing else makes such a write
  /// visible: neither a read nor a setting's `invalidate` goes back to the
  /// backend.
  ///
  /// The writes issued before the call are waited for first, so the
  /// backend already holds them when it is read. Once loaded, every key is
  /// updated together and then the listeners of each key whose state
  /// changed are notified, as for a mutation, so the settings over them
  /// read the new values and tell their own listeners. A key that was
  /// written or removed while the reload ran keeps that newer state.
  ///
  /// Afterwards the storage reads as one created at that moment would. A
  /// key whose persistence had failed therefore reads what the backend
  /// holds, not the value that never reached it, and [flush] no longer
  /// fails for it: the unpersisted value is gone, as it would be after a
  /// restart.
  ///
  /// The future fails with what the backend throws when it cannot be
  /// read; the in-memory state is unchanged then. A storage whose backend
  /// nothing else can write (one in memory, a Hive box, which Hive locks)
  /// has nothing to load and completes without a change. A box layered
  /// over another storage reloads that storage, its other boxes included.
  ///
  /// This makes outside writes visible; it does not coordinate writers.
  /// Two isolates that write one key overwrite each other, and the last
  /// write to reach the backend stays.
  Future<void> reload();

  /// Closes this storage and releases its box (see the lifecycle section
  /// of the class documentation).
  ///
  /// The storage is closed at once: from the call on, every read, write,
  /// [reload] and [addKeyListener] throws a [StateError];
  /// [removeKeyListener] and [flush] stay allowed. The returned future completes once the
  /// operations issued before the call have been persisted, and fails
  /// like [flush] when one of them left a key unpersisted; the box is
  /// released either way. Closing again returns the same future.
  Future<void> close();

  /// Whether [close] has been called, so that reads and writes throw.
  bool get isClosed;

  /// Runs [mutations], the writes of one burst, and persists each key they
  /// changed once, afterwards, where that is cheaper than persisting every
  /// write on its own.
  ///
  /// A string-backed storage holds the writes back, including one over a
  /// DAO or secure storage. An in-memory storage, Hive and shared
  /// preferences just run [mutations]: each of their writes is already
  /// applied as it happens, and they have no cheaper bulk call to make. A
  /// storage over another (a box, a decorator) passes the burst on, so
  /// that the storage below can coalesce it.
  ///
  /// This is not a transaction. Inside [batch] every write updates the
  /// in-memory state and notifies that key's listeners immediately, so a
  /// setting read back during the burst sees the value just written.
  /// Notifying once at the end would leave another setting over the same
  /// key stale until the burst returned. A throw does not roll the writes
  /// back: what was written before it stays, in memory and in the
  /// persistence that follows.
  ///
  /// Each key is persisted once, with its final state, when the outermost
  /// [batch] returns. A backend that can send those writes in one round
  /// trip does; otherwise they go one after another. That round trip is a
  /// transaction only when the backend itself makes it one (a DAO that
  /// overrides `writeBatch`). Batches nest, and the writes wait for the
  /// outermost call. A [flush] inside the burst covers the writes of the
  /// burst as well. A [clear] inside it drops what the burst wrote before
  /// the clear and keeps what it writes after.
  void batch(void Function() mutations);
}
