import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';

void main() {
  const english = Locale('en');

  late RecordingObserver observer;
  late InMemoryStorage storage;

  setUp(() {
    observer = RecordingObserver();
    storage = InMemoryStorage(observer: observer);
  });

  group('LocaleSubtagsCodec', () {
    const codec = LocaleSubtagsCodec();

    test('round-trips a language, a script and a region', () {
      for (final locale in const [
        Locale('en'),
        Locale('en', 'US'),
        Locale('es', '419'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN'),
        Locale.fromSubtags(languageCode: 'sr', scriptCode: 'Latn'),
      ]) {
        expect(codec.decode(codec.encode(locale)), locale, reason: '$locale');
      }
      expect(codec.encode(const Locale('en', 'US')), 'en-US');
    });

    test('reads the underscore form the platform writes', () {
      expect(codec.decode('pt_BR'), const Locale('pt', 'BR'));
    });

    test('rejects what is not a language with an optional script and region', () {
      for (final raw in ['', 'e', 'en-', 'en-US-x-private', 'de-DE-1996', '12', 'en US']) {
        expect(() => codec.decode(raw), throwsFormatException, reason: raw);
      }
    });

    test('rejects a locale whose own subtags are not a language, script and region', () {
      expect(() => codec.encode(const Locale('en-US-x-private')), throwsFormatException);
      expect(
        () => codec.encode(const Locale.fromSubtags(languageCode: 'de', countryCode: 'DE-1996')),
        throwsFormatException,
      );
    });
  });

  test('LocaleSetting stores the language tag and a fresh instance reads it back', () {
    LocaleSetting(storage: storage, key: 'k', defaultValue: english).value = const Locale('de', 'AT');

    expect(storage.getString('k'), 'de-AT');
    expect(LocaleSetting(storage: storage, key: 'k', defaultValue: english).value, const Locale('de', 'AT'));
  });

  test('LocaleSetting does not store a locale whose tag it cannot read back', () {
    final setting = LocaleSetting(storage: storage, key: 'k', defaultValue: english);

    expect(() => setting.value = const Locale('en-US-x-private'), throwsFormatException);
    expect(setting.value, english);
    expect(storage.getString('k'), isNull);
  });

  test('LocaleSetting falls back to the default for a tag it cannot read, and reports it', () {
    storage.setString('k', 'not a tag');

    expect(LocaleSetting(storage: storage, key: 'k', defaultValue: english).value, english);
    expect(observer.events.single, isA<DecodeFallbackEvent>());
  });

  group('LocaleValidator', () {
    test('accepts a listed locale and rejects one that differs by region', () {
      final validator = LocaleValidator<Locale>(const [Locale('en'), Locale('de', 'AT')]);

      expect(validator.validateRead(const Locale('en')), isNull);
      expect(validator.validateRead(const Locale('de', 'AT')), isNull);
      expect(validator.validateRead(const Locale('en', 'US')), isA<ForbiddenValueValidationError<Locale>>());
      expect(validator.validateRead(const Locale('fr')), isA<ForbiddenValueValidationError<Locale>>());
    });

    test('lets null pass', () {
      final validator = LocaleValidator<Locale?>(const [Locale('en')]);

      expect(validator.validateRead(null), isNull);
      expect(validator.validateRead(const Locale('fr')), isA<ForbiddenValueValidationError<Locale?>>());
    });

    test('rejects an empty list', () {
      expect(() => LocaleValidator(const <Locale>[]), throwsArgumentError);
    });
  });

  test('LocaleSetting falls back when the stored locale is not one the validator lists', () {
    storage.setString('k', 'fr');

    final setting = LocaleSetting(
      storage: storage,
      key: 'k',
      defaultValue: english,
      validator: LocaleValidator(const [Locale('en'), Locale('de')]),
    );

    expect(setting.value, english);
    expect(observer.events.single, isA<ValidationFallbackEvent>());
  });

  test('LocaleSetting does not store a locale the validator does not list', () {
    final setting = LocaleSetting(
      storage: storage,
      key: 'k',
      defaultValue: english,
      validator: LocaleValidator(const [english], debugDescription: 'supported'),
    );

    expect(() => setting.value = const Locale('fr'), throwsA(isA<SettingValidationException>()));
    expect(setting.value, english);
    expect(storage.getString('k'), isNull);
  });

  test('LocaleNullableSetting stores null, the "follow the device" choice, apart from the default', () {
    final setting = LocaleNullableSetting(storage: storage, key: 'k', defaultValue: english)..value = null;

    expect(setting.value, isNull);
    expect(LocaleNullableSetting(storage: storage, key: 'k', defaultValue: english).value, isNull);
    setting.reset();
    expect(setting.value, english);
  });
}
