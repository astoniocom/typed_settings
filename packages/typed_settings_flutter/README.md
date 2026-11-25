# typed_settings_flutter

Flutter bindings and Material setting tiles for
[`typed_settings`](https://pub.dev/packages/typed_settings): bindings that
connect a setting to Flutter, and ready-made tiles that show a value and
edit it. A running web example is at
<https://astoniocom.github.io/typed_settings/>.

> The tiles are meant for prototyping a settings screen quickly. They do
> not support flexible customization: a tile takes a label, a subtitle, an
> icon and a few options of its control, and its look follows the Material
> theme. A screen with its own design uses the bindings and its own widgets.

Import `package:typed_settings_flutter/typed_settings_flutter.dart` instead
of `package:typed_settings/typed_settings.dart`: it re-exports the core.

```dart
final storage = await SharedPreferencesStorage.create(
  box: 'app',
  observer: const FlutterErrorSettingsObserver(),
);
final volume = IntSetting(storage: storage, key: 'volume', defaultValue: 50);

// A settings screen:
SettingsErrorHandlerProvider(
  handler: const SnackbarSettingsErrorHandler(),
  child: ListView(
    children: [
      IntSettingTile(setting: volume, label: 'Volume', min: 0, max: 100),
    ],
  ),
);

// Anywhere else:
ValueListenableBuilder(
  valueListenable: volume,
  builder: (context, value, _) => Text('$value'),
);
```

## Tiles

| Tile | Edits |
| --- | --- |
| `BoolSwitchSettingTile`, `BoolCheckboxSettingTile` | a `bool` with a switch or a checkbox |
| `BoolNullableCheckboxSettingTile`, `BoolNullableDropdownSettingTile` | a `bool?` with a tristate checkbox or a menu |
| `IntSettingTile` | an `int` in a number field, within `min` and `max` |
| `DoubleSettingTile` | a `double` with a slider between `min` and `max` |
| `StringSettingTile` | a `String` in a text field |
| `EnumSettingTile` | an enum constant picked from a menu |
| `ThemeSettingTile` | a `ThemeMode` with a segmented button: light, system, dark |
| `DateTimeSettingTile` | a `DateTime` with the date picker, then the time picker unless `pickTime: false` |
| `TimeOfDaySettingTile` | a `TimeOfDay` with the time picker |
| `DurationSettingTile` | a `Duration` in hours, minutes and seconds |
| `ColorSettingTile` | a `Color` in a color picker |
| `LocaleSettingTile` | a `Locale` picked from the listed locales |
| `StringListSettingTile`, `IntListSettingTile` | a list in a dialog that adds, removes and reorders items |
| `MapSettingTile` | a `Map<String, Object?>` as JSON |

Except the theme and list tiles, each from `int` on has a nullable variant
(`IntNullableSettingTile`, ...) that can also clear the value to `null`.
The same control without `Setting` in the name (`IntTile`, `EnumTile`, ...)
edits a `ValueNotifier`, for a screen that is not backed by a setting yet.
There are no tiles for bytes, `Uri`, sets, ranges, `JsonSetting` and
`ListSetting` of other element types. A map checked against a JSON Schema
is edited with
[`typed_settings_json_schema_flutter`](https://pub.dev/packages/typed_settings_json_schema_flutter).

`SettingsErrorHandlerProvider` with a `SettingsErrorHandler`
(`SnackbarSettingsErrorHandler`, `DialogSettingsErrorHandler`) decides how
a tile reports a value the setting rejects.

A tile of your own that looks like the built-in ones is built from
`package:typed_settings_flutter/typed_settings_flutter_extend.dart`:
`SettingsTile`, `ValueChip`, `CountBadge`, `DialogResult` and the date and
time pickers the tiles use.

## Bindings and Flutter types

- `setting.editorView(context, label: ...)`: a `ValueNotifier` view for a
  widget that edits one. A rejected value goes to the
  `SettingsErrorHandler` above `context`. The core has
  `setting.asValueNotifier(onValidationError: ...)` for the same without a
  `BuildContext`. Reading needs neither: a setting is a `ValueListenable`.
- Settings of Flutter types: `ColorSetting`, `LocaleSetting` (with
  `LocaleValidator`), `TimeOfDaySetting` and `TimeOfDayRangeSetting`, each
  with a nullable variant. `AppliedLocale` reads a `ValueListenable<Locale?>`
  and gives the locale for `MaterialApp` when `null` means "follow the device".
- `FlutterErrorSettingsObserver`: reports diagnostics through
  `FlutterError`, so they reach the crash reporter in release builds.
- `TypedSettingsLocalizations`: the editor text Material does not have.
  English unless a subclass is installed with a `Localizations` delegate.

Requires Flutter 3.50: the first release whose `ValueListenable` is the one
from `package:listen` that a setting implements. The tiles use
`material_ui`.
