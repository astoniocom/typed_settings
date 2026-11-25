import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings_dao.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_drift/typed_settings_drift.dart';
import 'package:typed_settings_example/app_settings.dart';
import 'package:typed_settings_example/drift_db/database.dart';
import 'package:typed_settings_example/home_page.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';
import 'package:typed_settings_hive/typed_settings_hive.dart';
import 'package:typed_settings_secure_storage/typed_settings_secure_storage.dart';
import 'package:typed_settings_shared_preferences/typed_settings_shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The storages are independent, so they load concurrently: startup waits
  // for the slowest of them, not for their sum.
  final [
    sharedPreferencesSettings,
    hiveSettings,
    driftSettings,
    secureStorageSettings,
    inMemorySettings,
  ] = await [
    _initWithSharedPreferences(),
    _initWithHive(),
    _initWithDrift(),
    _initWithSecureStorage(),
    _initInMemorySettings(),
  ].wait;

  final tabs = <StorageTab>[
    (title: 'Shared Preferences', settings: sharedPreferencesSettings),
    (title: 'Hive', settings: hiveSettings),
    (title: 'Drift', settings: driftSettings),
    (title: 'Secure Storage', settings: secureStorageSettings),
    (title: 'In Memory', settings: inMemorySettings),
  ];

  // Settings are read and written synchronously; the write reaches the
  // storage in the background.
  for (final tab in tabs) {
    tab.settings.launchCount.value++;
  }

  runApp(App(tabs: tabs));
}

Future<AppSettings> _initWithSharedPreferences() async {
  final storage = await SharedPreferencesStorage.create(
    box: 'app',
    observer: const _ConsoleObserver(),
  );
  return AppSettings(storage: storage);
}

Future<AppSettings> _initWithHive() async {
  await Hive.initFlutter();
  final storage = await HiveStorage.create(
    box: 'app',
    observer: const _ConsoleObserver(),
  );
  return AppSettings(storage: storage);
}

Future<AppSettings> _initWithDrift() async {
  final database = AppDb();
  final dao = DriftSettingsDao(database, database.settingTable);
  final storage = await CachedDaoStorage.create(
    dao: dao,
    observer: const _ConsoleObserver(),
  );
  return AppSettings(storage: storage);
}

Future<AppSettings> _initWithSecureStorage() async {
  // A scope of its own where the platform has one, so that loading reads
  // and decrypts these settings alone, not every secret of the app.
  const scope = 'typed_settings_example';
  const flutterSecureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accountName: scope),
    mOptions: MacOsOptions(accountName: scope),
    aOptions: AndroidOptions(storageNamespace: scope),
    webOptions: WebOptions(dbName: scope),
  );
  final storage = await SecureStorage.create(
    storage: flutterSecureStorage,
    observer: const _ConsoleObserver(),
  );
  return AppSettings(storage: storage);
}

Future<AppSettings> _initInMemorySettings() async {
  return AppSettings(storage: InMemoryStorage(observer: const _ConsoleObserver()));
}

/// One sink for every diagnostic of a storage and of the settings using it:
/// unusable stored values, failed background writes.
final class _ConsoleObserver extends SettingsObserver {
  const _ConsoleObserver();

  @override
  void onEvent(SettingsEvent event) {
    debugPrint(event.message);
    final stackTrace = event.stackTrace;
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }
}

class App extends StatefulWidget {
  const App({required this.tabs, super.key});

  final List<StorageTab> tabs;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // Writes are persisted in the background. When the app leaves the screen
    // (and may be killed by the system), let the started writes reach the
    // storage.
    _lifecycleListener = AppLifecycleListener(
      onHide: _flushAll,
      onDetach: _flushAll,
    );
  }

  void _flushAll() {
    for (final tab in widget.tabs) {
      // A write that did not persist was reported to the storage's observer
      // when it failed; while the app is leaving there is nothing to add.
      tab.settings.storage.flush().ignore();
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    for (final tab in widget.tabs) {
      // Fails like the flush above, for writes already reported.
      tab.settings.close().ignore();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'typed_settings example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo),
      darkTheme: ThemeData(colorSchemeSeed: Colors.indigo, brightness: Brightness.dark),
      home: HomePage(tabs: widget.tabs),
    );
  }
}
