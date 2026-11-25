# typed_settings

Type-safe, reactive application settings with pluggable storage backends.
Pure Dart: the Flutter bindings and setting tiles are in
[`typed_settings_flutter`](https://pub.dev/packages/typed_settings_flutter).
A running web example is at <https://astoniocom.github.io/typed_settings/>.

A setting is declared once, with its key, type, default value and
validation, and is then read and written synchronously from anywhere:

```dart
final volume = IntSetting(
  storage: storage,
  key: 'volume',
  defaultValue: 50,
  validator: SettingValidator.range(min: 0, max: 100),
);

volume.value = 80; // in memory now, persisted in the background
volume.addListener(() => print(volume.value));
volume.value = 150; // throws a SettingValidationException
volume.reset(); // back to 50
```

## Setting types

| Setting | Value |
| --- | --- |
| `BoolSetting` | `bool` |
| `IntSetting` | `int` |
| `DoubleSetting` | `double` |
| `StringSetting` | `String` |
| `EnumSetting` | one constant of an enum |
| `EnumSetSetting` | a set of constants of an enum |
| `DateTimeSetting` | a moment in time |
| `DateSetting` | a calendar date, without a time of day |
| `DurationSetting` | `Duration` |
| `UriSetting` | `Uri` |
| `BytesSetting` | `Uint8List`, stored as Base64 |
| `StringListSetting`, `IntListSetting` | `List<String>`, `List<int>` |
| `StringSetSetting` | `Set<String>` |
| `ListSetting`, `SetSetting` | a list or a set of any element type, through `fromJson` / `toJson` |
| `MapSetting` | a JSON-like `Map<String, Object?>` |
| `JsonSetting` | a model class with `fromJson` / `toJson` (json_serializable, freezed) |
| `RangeSetting` | a from-to pair (`ValueRange`); `ofInt`, `ofDouble`, `ofDuration`, `ofDateTime` |

Each has a nullable variant (`IntNullableSetting`, ...) in which `null` is
a stored value distinct from "not set". [`typed_settings_flutter`](https://pub.dev/packages/typed_settings_flutter) adds
`ColorSetting`, `LocaleSetting`, `TimeOfDaySetting` and
`TimeOfDayRangeSetting`; [`typed_settings_json_schema`](https://pub.dev/packages/typed_settings_json_schema) adds map settings
checked against a JSON Schema.

## A type of your own

A model class with `fromJson` and `toJson` (json_serializable, freezed) is a
`JsonSetting`.

```dart
final filter = JsonSetting(
  storage: storage,
  key: 'filter',
  defaultValue: const Filter(),
  fromJson: Filter.fromJson,
  toJson: (filter) => filter.toJson(),
);
```

Any other representation is a `SettingCodec` plus a `StoredSetting`, from
`package:typed_settings/typed_settings_extend.dart`.

```dart
final class PointCodec implements SettingCodec<Point, String> {
  const PointCodec();

  @override
  Point decode(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) throw FormatException('Expected `x,y`', raw);
    return Point(int.parse(parts[0]), int.parse(parts[1]));
  }

  @override
  String encode(Point value) => '${value.x},${value.y}';
}

final origin = StoredSetting(
  slot: KeyedSettingSlot.ofString(storage, key: 'origin'),
  codec: const PointCodec(),
  defaultValue: const Point(0, 0),
);
```

A type that already parses a string of its own (`BigInt.parse`, a version)
uses `ParsedStringCodec` instead of a codec class. `JsonNullableSetting`
and `StoredNullableSetting` are the nullable forms: `null` is stored
explicitly and is distinct from nothing stored.

## Features

- Synchronous reads from an in-memory cache; writes persist in the
  background, in order, and `flush()` waits for them and reports the ones
  that failed. A storage created with `persistenceDelay:` writes only the
  latest value of a key that changes in a burst (a slider).
- Validation on write and on read: a stored value that no longer passes
  falls back to the default and is reported, instead of crashing the app.
- A setting is a `ValueListenable` of `package:listen`, so with Flutter
  3.50 or later, which exports that type, a `ValueListenableBuilder` takes
  the setting itself. `asValueNotifier()` gives a `ValueNotifier` view to
  an API that edits one.
- Listeners, streams, `commit()` for a write that must be confirmed, and
  migrations of renamed keys (`legacyKeys`).
- Diagnostics go to a `SettingsObserver` you choose, without stored values
  in release builds.
- Boxes: several independent groups of settings in one backend.

## Storages

| Package | Storage |
| --- | --- |
| this package, `typed_settings_in_memory.dart` | `InMemoryStorage`, for tests and prototypes |
| this package, `typed_settings_dao.dart` | `CachedDaoStorage` over your own table |
| [`typed_settings_shared_preferences`](https://pub.dev/packages/typed_settings_shared_preferences) | SharedPreferences |
| [`typed_settings_hive`](https://pub.dev/packages/typed_settings_hive) | Hive CE |
| [`typed_settings_secure_storage`](https://pub.dev/packages/typed_settings_secure_storage) | flutter_secure_storage |
| [`typed_settings_drift`](https://pub.dev/packages/typed_settings_drift) | a drift (SQLite) table, through `CachedDaoStorage` |

## Libraries

- `typed_settings.dart`: the presets, storages' common interface,
  validation and diagnostics. Most applications need only this one and the
  library of their storage.
- `typed_settings_contract.dart`: `Setting` and validation alone, for code
  that uses a setting without creating one.
- `typed_settings_extend.dart`: codecs, slots and `StoredSetting`, for a
  setting of a new kind.
- `typed_settings_backend.dart`: the building blocks of a storage over a
  new backend; check it with
  [`typed_settings_conformance`](https://pub.dev/packages/typed_settings_conformance).

See [`example/main.dart`](example/main.dart) for a runnable example.
