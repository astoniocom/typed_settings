# typed_settings example

One set of settings (`lib/app_settings.dart`) over five storages, one tab each:
SharedPreferences, Hive, Drift (a `SettingsDao`), flutter_secure_storage and
memory. Every tile of `typed_settings_flutter` and
`typed_settings_json_schema_flutter` is on the page (`lib/settings_page.dart`);
its subtitle names the tile and the value the setting rejects, so that the
error handler (a snackbar) can be tried.

The theme mode and accent color of a tab theme that tab, and the launch count
grows at every start, which shows that the storage persists.

```sh
flutter run
```
