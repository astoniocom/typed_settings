# typed_settings_secure_storage

[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
storage for [`typed_settings`](https://pub.dev/packages/typed_settings):
settings kept encrypted in the Keychain, the Android Keystore and their
counterparts on other platforms.

```dart
const flutterSecureStorage = FlutterSecureStorage(
  iOptions: IOSOptions(accountName: 'my_app_settings'),
  aOptions: AndroidOptions(storageNamespace: 'my_app_settings'),
);

final storage = await SecureStorage.create(storage: flutterSecureStorage, box: 'tokens');
final apiToken = StringNullableSetting(storage: storage, key: 'api_token');
```

`create` loads the box into memory, so reads are synchronous; writes reach
the platform in the background, one at a time, and `flush()` waits for
them. Values are stored as strings that record their type. With
`persistenceDelay:` a write of a key reaches the platform only once the key
has not changed for that long, or on `flush()`.

The platform can only read everything stored with the same options at once:
every box, and any other secret the application keeps there. Give the
settings a scope of their own where the platform has one (`accountName` on
Apple platforms, `storageNamespace` on Android, `dbName` on the web), so
that loading them does not read and decrypt the rest. Linux and Windows
have no such scope.

Boxes share one scope under a `<box>.` prefix; box names and setting keys
must not contain `.`. `clear()` removes one box, `clearAll()` everything
stored with the same options.
