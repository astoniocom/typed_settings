import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show TimeOfDay;
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';

void main() {
  const nine = TimeOfDay(hour: 9, minute: 0);

  late RecordingObserver observer;
  late InMemoryStorage storage;

  setUp(() {
    observer = RecordingObserver();
    storage = InMemoryStorage(observer: observer);
  });

  group('TimeOfDayMinutesCodec', () {
    const codec = TimeOfDayMinutesCodec();

    test('stores the minutes since midnight', () {
      expect(codec.encode(const TimeOfDay(hour: 0, minute: 0)), 0);
      expect(codec.encode(const TimeOfDay(hour: 23, minute: 59)), 1439);
      expect(codec.decode(9 * 60 + 30), const TimeOfDay(hour: 9, minute: 30));
    });

    test('rejects minutes outside the day', () {
      expect(() => codec.decode(-1), throwsFormatException);
      expect(() => codec.decode(1440), throwsFormatException);
    });

    test('rejects a time outside the day', () {
      expect(() => codec.encode(const TimeOfDay(hour: 24, minute: 0)), throwsFormatException);
      expect(() => codec.encode(const TimeOfDay(hour: -1, minute: 0)), throwsFormatException);
      expect(() => codec.encode(const TimeOfDay(hour: 10, minute: 60)), throwsFormatException);
      expect(() => codec.encode(const TimeOfDay(hour: 10, minute: -1)), throwsFormatException);
    });
  });

  test('TimeOfDaySetting stores the minutes and a fresh instance reads them back', () {
    TimeOfDaySetting(storage: storage, key: 'k', defaultValue: nine).value = const TimeOfDay(hour: 22, minute: 15);

    expect(storage.getInt('k'), 22 * 60 + 15);
    expect(
      TimeOfDaySetting(storage: storage, key: 'k', defaultValue: nine).value,
      const TimeOfDay(hour: 22, minute: 15),
    );
  });

  test('TimeOfDaySetting refuses a time outside the day and keeps the stored one', () {
    final setting = TimeOfDaySetting(storage: storage, key: 'k', defaultValue: nine)
      ..value = const TimeOfDay(hour: 22, minute: 15);

    expect(() => setting.value = const TimeOfDay(hour: 24, minute: 0), throwsFormatException);
    expect(setting.value, const TimeOfDay(hour: 22, minute: 15));
    expect(storage.getInt('k'), 22 * 60 + 15);
  });

  test('TimeOfDaySetting falls back to the default for minutes outside the day, and reports it', () {
    storage.setInt('k', 5000);

    expect(TimeOfDaySetting(storage: storage, key: 'k', defaultValue: nine).value, nine);
    expect(observer.events.single, isA<DecodeFallbackEvent>());
  });

  test('TimeOfDayNullableSetting stores null apart from the default', () {
    final setting = TimeOfDayNullableSetting(storage: storage, key: 'k', defaultValue: nine)..value = null;

    expect(storage.hasNull('k'), isTrue);
    expect(TimeOfDayNullableSetting(storage: storage, key: 'k', defaultValue: nine).value, isNull);
    setting.reset();
    expect(setting.value, nine);
  });

  const quietHours = ValueRange<TimeOfDay>(
    start: TimeOfDay(hour: 22, minute: 0),
    end: TimeOfDay(hour: 7, minute: 0),
  );

  test('TimeOfDayRangeSetting stores an end that is earlier than the start', () {
    TimeOfDayRangeSetting(storage: storage, key: 'k', defaultValue: quietHours).value = const ValueRange(
      start: TimeOfDay(hour: 9, minute: 0),
      end: TimeOfDay(hour: 17, minute: 30),
    );

    expect(storage.getString('k'), '[540,1050]');
    expect(
      TimeOfDayRangeSetting(storage: storage, key: 'k', defaultValue: quietHours).value,
      const ValueRange<TimeOfDay>(start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 17, minute: 30)),
    );

    TimeOfDayRangeSetting(storage: storage, key: 'k', defaultValue: quietHours).value = quietHours;
    expect(storage.getString('k'), '[1320,420]');
    expect(TimeOfDayRangeSetting(storage: storage, key: 'k', defaultValue: quietHours).value, quietHours);
  });

  test('TimeOfDayRangeSetting falls back when an end is not a time of day, and reports it', () {
    storage.setString('k', '[0,2000]');

    expect(TimeOfDayRangeSetting(storage: storage, key: 'k', defaultValue: quietHours).value, quietHours);
    expect(observer.events.single, isA<DecodeFallbackEvent>());
  });

  test('TimeOfDayRangeNullableSetting stores null apart from the default', () {
    final setting = TimeOfDayRangeNullableSetting(storage: storage, key: 'k', defaultValue: quietHours)..value = null;

    expect(storage.hasNull('k'), isTrue);
    expect(TimeOfDayRangeNullableSetting(storage: storage, key: 'k', defaultValue: quietHours).value, isNull);
    setting.reset();
    expect(setting.value, quietHours);
  });
}
