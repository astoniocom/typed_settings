# typed_settings_shared_preferences

[SharedPreferences](https://pub.dev/packages/shared_preferences) storage for
[`typed_settings`](https://pub.dev/packages/typed_settings).

```dart
import 'package:flutter/widgets.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_shared_preferences/typed_settings_shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await SharedPreferencesStorage.create(box: 'settings');
  final launchCount = IntSetting(storage: storage, key: 'launch_count', defaultValue: 0);
  launchCount.value++;
}
```

The storage is built on `SharedPreferencesAsync` and keeps its own cache:
`create` loads the preferences, reads are synchronous, and writes reach the
platform in the background, one at a time, those of one key in the order
they were made.
`flush()` waits for them, and `reload()` picks up what native code or
another isolate wrote. With `persistenceDelay:` a write of a key reaches
the platform only once the key has not changed for that long, or on
`flush()`, so a slider makes one platform call instead of dozens. `SharedPreferencesWithCache` is not used: its writes
reach the platform in no guaranteed order, and its reload empties the cache
while it fetches.

`bool`, `int` and `double` are stored as the platform's own types. A string
and an explicit `null` share the platform's string type, so both are stored
with a type tag: an explicit `null` is not an absent key, and a string cannot
be that tag.

Boxes share the preference key space under a `<box>.` prefix; box names
must not contain `.` or `\`. Pass `options:` to `create` for the platform
options of `SharedPreferencesAsync`, such as the Android backend.
