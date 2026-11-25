import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

import 'package:typed_settings_conformance/typed_settings_conformance.dart';

void main() {
  const oneToTen = ValueRange<int>(start: 1, end: 10);

  late RecordingObserver observer;
  late InMemoryStorage storage;

  setUp(() {
    observer = RecordingObserver();
    storage = InMemoryStorage(observer: observer);
  });

  group('JsonRangeCodec', () {
    const codec = JsonRangeCodec<int>(fromJson: _intFromJson, toJson: _intToJson);

    test('stores two ends and reads them back', () {
      expect(codec.encode(oneToTen), '[1,10]');
      expect(codec.decode('[1,10]'), oneToTen);
      expect(codec.decode('[4,4]'), const ValueRange<int>(start: 4, end: 4));
    });

    test('rejects a text that is not an array of two elements', () {
      for (final raw in ['{', '{"a":1}', '[1]', '[1,2,3]', '1']) {
        expect(() => codec.decode(raw), throwsFormatException, reason: raw);
      }
    });

    test('stores an inverted range as given', () {
      const inverted = ValueRange<int>(start: 10, end: 1);
      expect(codec.decode(codec.encode(inverted)), inverted);
    });
  });

  test('ofInt refuses an inverted range as a validation error and keeps the stored one', () {
    const inverted = ValueRange<int>(start: 5, end: 0);
    final setting = RangeSetting.ofInt(storage: storage, key: 'k', defaultValue: oneToTen)
      ..value = const ValueRange(start: 0, end: 5);

    expect(setting.validate(inverted), isA<ForbiddenValueValidationError<Object?>>());
    expect(() => setting.value = inverted, throwsA(isA<SettingValidationException>()));
    expect(setting.value, const ValueRange<int>(start: 0, end: 5));
    expect(storage.getString('k'), '[0,5]');
  });

  test('the order is checked before the validator', () {
    final setting = RangeSetting.ofInt(
      storage: storage,
      key: 'k',
      defaultValue: oneToTen,
      validator: SettingValidator((range) => range.end > 100 ? const RequiredValidationError() : null),
    );

    expect(setting.validate(const ValueRange(start: 500, end: 200)), isA<ForbiddenValueValidationError<Object?>>());
    expect(setting.validate(const ValueRange(start: 0, end: 200)), isA<RequiredValidationError>());
    expect(setting.validate(const ValueRange(start: 0, end: 20)), isNull);
  });

  test('ofInt falls back when the stored array is inverted or not two elements, and reports it', () {
    storage.setString('k', '[10,1]');
    final setting = RangeSetting.ofInt(storage: storage, key: 'k', defaultValue: oneToTen);

    expect(setting.value, oneToTen);
    expect(observer.events.single, isA<ValidationFallbackEvent>());

    observer.events.clear();
    storage.setString('k', '[1]');
    expect(setting.value, oneToTen);
    expect(observer.events.single, isA<DecodeFallbackEvent>());
  });

  test('ofDouble reads JSON integers as doubles', () {
    storage.setString('k', '[1,2]');

    expect(
      RangeSetting.ofDouble(storage: storage, key: 'k', defaultValue: const ValueRange(start: 0, end: 1)).value,
      const ValueRange<double>(start: 1, end: 2),
    );
  });

  test('a range without compare stores an end that is before the start', () {
    const inverted = ValueRange<int>(start: 5, end: 1);
    final setting = RangeSetting<int>(
      storage: storage,
      key: 'k',
      defaultValue: inverted,
      fromJson: _intFromJson,
      toJson: _intToJson,
    );

    expect(setting.value, inverted);
    expect(storage.contents, isEmpty, reason: 'the default is not written by being read');
    setting.value = inverted;
    expect(storage.getString('k'), '[5,1]');
  });

  test('ofInt rejects an inverted default', () {
    expect(
      () => RangeSetting.ofInt(storage: storage, key: 'k', defaultValue: const ValueRange(start: 2, end: 1)),
      throwsArgumentError,
    );
  });

  test('ofInt nullable stores null apart from the default', () {
    final setting = RangeNullableSetting.ofInt(storage: storage, key: 'k', defaultValue: oneToTen)..value = null;

    expect(storage.hasNull('k'), isTrue);
    expect(RangeNullableSetting.ofInt(storage: storage, key: 'k', defaultValue: oneToTen).value, isNull);
    setting.reset();
    expect(setting.value, oneToTen);
  });

  test('ofInt nullable refuses an inverted range and lets null pass', () {
    final setting = RangeNullableSetting.ofInt(storage: storage, key: 'k');

    expect(setting.validate(const ValueRange(start: 2, end: 1)), isA<ForbiddenValueValidationError<Object?>>());
    expect(setting.validate(null), isNull);
  });
}

int _intFromJson(Object? json) => json! as int;

Object? _intToJson(int value) => value;
