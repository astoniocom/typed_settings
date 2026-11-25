import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_json_schema/typed_settings_json_schema.dart';

final class _RecordingObserver extends SettingsObserver {
  final List<SettingsEvent> events = [];

  @override
  void onEvent(SettingsEvent event) => events.add(event);
}

void main() {
  final schema = Schema.fromMap({
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'age': {'type': 'integer', 'minimum': 0},
    },
    'required': ['name'],
  });

  late InMemoryStorage storage;

  setUp(() => storage = InMemoryStorage());

  group('JsonSchemaValidator', () {
    test('accepts conforming maps and null, rejects violations with messages', () {
      final validator = JsonSchemaValidator<Map<String, Object?>?>(schema);

      expect(validator.validateRead({'name': 'a', 'age': 1}), isNull);
      expect(validator.validateRead(null), isNull);

      final error = validator.validateWrite({'age': -1});
      expect(error, isA<JsonSchemaValidationError>());
      expect((error! as JsonSchemaValidationError).messages, isNotEmpty);
    });
  });

  group('JsonSchemaMapSetting', () {
    test('rejects a violating write and keeps the previous value', () {
      final setting = JsonSchemaMapSetting(
        storage: storage,
        key: 'k',
        defaultValue: const {'name': 'd'},
        schema: schema,
      );

      expect(() => setting.value = {'age': 1}, throwsA(isA<SettingValidationException>()));
      expect(setting.value, {'name': 'd'});
    });

    test('a violating stored value falls back to defaultValue', () {
      final observer = _RecordingObserver();
      final setting = JsonSchemaMapSetting(
        storage: InMemoryStorage(observer: observer)..setString('k', '{"age":1}'),
        key: 'k',
        defaultValue: const {'name': 'd'},
        schema: schema,
      );

      expect(setting.value, {'name': 'd'});
      expect(
        observer.events.single,
        isA<ValidationFallbackEvent>().having((e) => e.error, 'error', isA<JsonSchemaValidationError>()),
      );
    });

    test('an extra validator runs after the schema check', () {
      const noBob = ForbiddenValueValidationError('bob');
      final setting = JsonSchemaMapSetting(
        storage: storage,
        key: 'k',
        defaultValue: const {'name': 'd'},
        schema: schema,
        validator: SettingValidator((map) => map['name'] == 'bob' ? noBob : null),
      );

      expect(setting.validate({'name': 'alice'}), isNull);
      expect(setting.validate({'name': 'bob'}), noBob);
      expect(setting.validate({'age': 1}), isA<JsonSchemaValidationError>(), reason: 'schema is checked first');
    });

    test('reads a legacy key and moves its value on the first write, like every preset', () async {
      storage.setString('old', '{"name":"Bob"}');
      final setting = JsonSchemaMapSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old'],
        defaultValue: const {'name': 'd'},
        schema: schema,
      );

      expect(setting.value, {'name': 'Bob'});
      setting.value = {'name': 'Alice'};
      await pumpEventQueue();
      expect(storage.getString('old'), isNull);
      expect(storage.getString('new'), '{"name":"Alice"}');
    });
  });

  group('JsonSchemaMapNullableSetting', () {
    test('null passes the schema and round-trips', () {
      final setting = JsonSchemaMapNullableSetting(storage: storage, key: 'k', schema: schema);

      setting.value = {'name': 'a'};
      expect(setting.value, {'name': 'a'});

      setting.value = null;
      setting.invalidate();
      expect(setting.value, isNull);
    });

    test('reads a legacy key, like every preset', () {
      storage.setString('old', '{"name":"Bob"}');
      final setting = JsonSchemaMapNullableSetting(
        storage: storage,
        key: 'new',
        legacyKeys: const ['old'],
        schema: schema,
      );

      expect(setting.value, {'name': 'Bob'});
    });
  });
}
