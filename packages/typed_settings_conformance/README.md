# typed_settings_conformance

The storage contract of [`typed_settings`](https://pub.dev/packages/typed_settings)
as an executable test suite, for authors of a storage backend: typed
values, explicit `null`, ordering of writes, `flush`, key listeners,
`reload` and `close`.

Add it as a dev dependency and call `storageConformance` from a test with a
factory that creates a fresh storage:

```dart
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

void main() {
  storageConformance(
    'MyStorage',
    (observer) => MyStorage.create(observer: observer),
    // Optional: writes a key behind the storage's back, to check reload.
    writeOutside: (storage, key, value) => writeDirectly(key, value),
  );
}
```

`RecordingObserver` collects the events a storage reports, for tests of
your own.
