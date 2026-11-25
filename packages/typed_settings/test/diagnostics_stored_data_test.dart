import 'package:test/test.dart';
import 'package:typed_settings/src/codec/json_element_converters.dart';
import 'package:typed_settings/src/diagnostics/stored_data.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

void main() {
  const secret = 'secret-123';

  Matcher describedWithoutSecret(SettingsEvent event) => isA<SettingsEvent>()
      .having((e) => e.describe(includeData: false), 'without data', isNot(contains(secret)))
      .having((e) => e.describe(includeData: true), 'with data', contains(secret));

  group('events', () {
    test('leave the stored data out of their description unless asked to include it', () {
      const source = FormatException('Unexpected character', '{"token": "$secret"', 3);
      final events = <SettingsEvent>[
        const StorageReadErrorEvent(key: 'k', raw: secret, error: FormatException('Expected an int')),
        PersistErrorEvent(key: 'k', error: source, stackTrace: StackTrace.current),
        for (final listenerSource in [ListenerSource.storageKey, ListenerSource.setting])
          ListenerErrorEvent(source: listenerSource, key: 'k', error: source, stackTrace: StackTrace.current),
      ];

      for (final event in events) {
        expect(event, describedWithoutSecret(event));
        expect(event.describe(includeData: false), contains('`k`'));
        expect(event.message, event.describe(includeData: true), reason: 'tests run as a debug build');
      }
      expect(events[1].describe(includeData: false), allOf(contains('Unexpected character'), contains('offset 3')));
    });

    test('a listener error names what the listener was registered with', () {
      String describe(ListenerSource source, String? key) => ListenerErrorEvent(
        source: source,
        key: key,
        error: 'boom',
        stackTrace: StackTrace.current,
      ).describe(includeData: false);

      expect(describe(ListenerSource.storageKey, 'k'), 'A listener of `k` threw: boom');
      expect(describe(ListenerSource.slot, null), 'A listener of the slot threw: boom');
      expect(describe(ListenerSource.setting, 'k'), 'A listener of setting `k` threw: boom');
      expect(describe(ListenerSource.setting, null), 'A listener of the setting threw: boom');
    });

    test('a decode fallback keeps the stored JSON out of the description, in the source of its error', () {
      final observer = RecordingObserver();
      final storage = InMemoryStorage(observer: observer)..setString('m', '{"token": "$secret"');
      expect(MapSetting(storage: storage, key: 'm', defaultValue: const {}).value, isEmpty);

      final event = observer.events.single as DecodeFallbackEvent;
      expect(event, describedWithoutSecret(event));
      expect((event.error as FormatException).source, contains(secret));
    });

    test('a decode fallback names an Error by its type alone, unless it is a TypeError', () {
      final setting = IntSetting(storage: InMemoryStorage(), key: 'k', defaultValue: 0);
      final quoting = DecodeFallbackEvent(
        key: setting.diagnosticKey,
        error: ArgumentError.value(secret),
        stackTrace: StackTrace.current,
      );
      expect(quoting, describedWithoutSecret(quoting));
      expect(quoting.describe(includeData: false), contains('ArgumentError'));

      final typeError = _thrownBy(() => _secretObject as int);
      final cast = DecodeFallbackEvent(key: setting.diagnosticKey, error: typeError, stackTrace: StackTrace.current);
      expect(cast.describe(includeData: false), endsWith('$typeError'));
    });

    test('a validation fallback describes its error by the debugDescription alone', () {
      final observer = RecordingObserver();
      final storage = InMemoryStorage(observer: observer)..setInt('k', 42);
      final setting = IntSetting(
        storage: storage,
        key: 'k',
        defaultValue: 0,
        validator: SettingValidator.range(max: 10, debugDescription: 'at most ten'),
      );
      expect(setting.value, 0);

      final event = observer.events.single as ValidationFallbackEvent;
      expect(event.describe(includeData: false), allOf(contains('at most ten'), isNot(contains('42'))));
      expect(event.describe(includeData: true), contains('42'));
    });

    test('hand the error on unchanged as the reportable error in a debug build', () {
      const error = FormatException('Unexpected character', secret);
      final event = PersistErrorEvent(key: 'k', error: error, stackTrace: StackTrace.current);

      expect(event.reportableError, same(error));
    });
  });

  group('ValidationError', () {
    test('describes itself by the debugDescription alone unless asked to include the data', () {
      const error = PatternValidationError(
        pattern: r'^\d+$',
        actual: 'alice@example.com',
        debugDescription: 'digits only',
      );

      expect(error.describe(includeData: false), allOf(contains('digits only'), isNot(contains('alice'))));
      expect(error.describe(includeData: true), contains('alice@example.com'));
      expect(error.toString(), error.describe(includeData: true), reason: 'tests run as a debug build');
    });
  });

  group('withoutStoredData', () {
    test('drops the source of a FormatException and keeps its message and offset', () {
      final stripped = withoutStoredData(const FormatException('Unexpected character', secret, 3));

      expect(
        stripped,
        isA<FormatException>().having((e) => e.source, 'source', isNull).having((e) => e.offset, 'offset', 3),
      );
      expect('$stripped', allOf(contains('Unexpected character'), isNot(contains(secret))));
    });

    test('returns anything else as it is', () {
      final error = StateError(secret);

      expect(withoutStoredData(error), same(error));
    });
  });

  group('decodeErrorWithoutStoredData', () {
    test('replaces an Error by one that keeps its type alone', () {
      final stripped = decodeErrorWithoutStoredData(ArgumentError.value(secret));

      expect(stripped, isA<Error>());
      expect('$stripped', allOf(contains('ArgumentError'), isNot(contains(secret))));
    });

    test('keeps a TypeError, whose message names types only', () {
      final typeError = _thrownBy(() => _secretObject as int);

      expect(decodeErrorWithoutStoredData(typeError), same(typeError));
      expect('$typeError', isNot(contains(_secretObject)));
    });

    test('drops the source of a FormatException, as withoutStoredData does', () {
      final stripped = decodeErrorWithoutStoredData(const FormatException('Unexpected character', secret, 3));

      expect(
        stripped,
        isA<FormatException>().having((e) => e.source, 'source', isNull).having((e) => e.offset, 'offset', 3),
      );
    });
  });

  group('the built-in codecs put the data they cannot decode into the source, not the message', () {
    Matcher sourceOnly(String data) => throwsA(
      isA<FormatException>()
          .having((e) => e.message, 'message', isNot(contains(data)))
          .having((e) => e.source, 'source', data),
    );

    test('EnumNameCodec', () {
      expect(() => EnumNameCodec(TestEnum.values).decode(secret), sourceOnly(secret));
    });

    test('the JSON list element converters', () {
      expect(() => intFromJson(secret), sourceOnly(secret));
      expect(() => stringFromJson(12345), sourceOnly('12345'));
    });

    test('DateTimeMillisCodec', () {
      expect(() => const DateTimeMillisCodec().decode(8640000000000001), sourceOnly('8640000000000001'));
    });
  });
}

enum TestEnum { a, b }

/// Stored data typed as `Object`, so that a cast of it is not known to fail
/// before it runs.
const Object _secretObject = 'secret-object-456';

/// What [body] throws.
Object _thrownBy(void Function() body) {
  try {
    body();
  } on Object catch (error) {
    return error;
  }
  throw StateError('expected a throw');
}
