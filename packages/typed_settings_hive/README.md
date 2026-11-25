# typed_settings_hive

[Hive CE](https://pub.dev/packages/hive_ce) storage for
[`typed_settings`](https://pub.dev/packages/typed_settings). Pure Dart, so it
works in Flutter and in command-line programs alike.

```dart
import 'package:hive_ce/hive_ce.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_hive/typed_settings_hive.dart';

Future<void> main() async {
  Hive.init('path/to/settings'); // Hive.initFlutter() of hive_ce_flutter in an app

  final storage = await HiveStorage.create(box: 'settings');
  final launchCount = IntSetting(storage: storage, key: 'launch_count', defaultValue: 0);
  launchCount.value++;

  await storage.close();
}
```

`HiveStorage.create` opens the Hive box of that name; `HiveStorage(box: ...)`
takes a box that is already open. Each box holds one group of settings, and
one open storage at a time serves it. Values use Hive's native types, and an
explicit `null` is stored as one.

Hive reads the whole box into memory when it opens it, so reads are
synchronous; writes reach the file in the background, and `flush()` waits
for them. `close()` closes the box too. With `persistenceDelay:` a write of
a key reaches the box only once the key has not changed for that long, or
on `flush()`; reading the `Box` directly meanwhile sees the previous value.

On the web nothing locks a box against another tab: a box another tab
writes is not reloaded, and has to be closed and opened again.
