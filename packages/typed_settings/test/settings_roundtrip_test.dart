import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

import 'package:typed_settings_conformance/typed_settings_conformance.dart';

enum Level { low, mid, high }

/// Contract every built-in setting class must satisfy, exercised through a
/// real storage: default, persistence across instances, dedup, reset, and
/// cache invalidation (hence [StoredSetting], not [Setting]).
void settingContract<T>(
  String name, {
  required StoredSetting<T, Object?> Function(InMemoryStorage storage) create,
  required T defaultValue,
  required T sample,
  required T other,
}) {
  group(name, () {
    late InMemoryStorage storage;
    late RecordingObserver observer;

    setUp(() {
      observer = RecordingObserver();
      storage = InMemoryStorage(observer: observer);
    });

    tearDown(() => expect(observer.events, isEmpty, reason: 'no diagnostics expected in the happy path'));

    test('returns defaultValue on empty storage and reports isDefault', () {
      final setting = create(storage);
      expect(setting.value, defaultValue);
      expect(setting.isDefault, isTrue);
      expect(storage.contents, isEmpty, reason: 'reading must not write');
    });

    test('persists the value and a fresh instance reads it back', () {
      create(storage).value = sample;

      final reread = create(storage);
      expect(reread.value, sample);
      expect(reread.isDefault, isFalse);
    });

    test('overwrites a previous value', () {
      final setting = create(storage)..value = sample;
      setting.value = other;
      expect(create(storage).value, other);
    });

    test('writing an equal value again does not notify', () {
      final setting = create(storage)..value = sample;
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = sample;

      expect(notifications, 0);
    });

    test('reset returns to defaultValue in cache and storage', () {
      final setting = create(storage)..value = sample;

      setting.reset();

      expect(setting.value, defaultValue);
      expect(setting.isDefault, isTrue);
      expect(create(storage).value, defaultValue);
    });

    test('a write through another instance is seen without invalidate', () {
      final setting = create(storage)..value = sample;
      var notifications = 0;
      setting.addListener(() => notifications++);

      create(storage).value = other;

      expect(notifications, 1);
      expect(setting.value, other);
    });

    test('invalidate re-reads from storage', () {
      final setting = create(storage)..value = sample;
      setting.invalidate();
      expect(setting.value, sample);
    });
  });
}

/// Additional contract for nullable settings: `null` is a stored value,
/// distinct from the (possibly non-null) default.
void nullableSettingContract<T extends Object>(
  String name, {
  required StoredSetting<T?, Object?> Function(InMemoryStorage storage, T? defaultValue) create,
  required T sample,
  required T other,
}) {
  settingContract<T?>(
    name,
    create: (storage) => create(storage, null),
    defaultValue: null,
    sample: sample,
    other: other,
  );

  group('$name with a non-null default', () {
    late InMemoryStorage storage;

    setUp(() => storage = InMemoryStorage(observer: _failOnEvent));

    test('null round-trips as a value distinct from the default', () {
      final setting = create(storage, other)..value = null;

      expect(setting.value, isNull);
      expect(setting.isDefault, isFalse);
      expect(create(storage, other).value, isNull, reason: 'explicit null survives a fresh instance');
    });

    test('reset after null returns to the default', () {
      final setting = create(storage, other)..value = null;

      setting.reset();

      expect(setting.value, other);
      expect(create(storage, other).value, other);
    });

    test('a value replaces an explicit null', () {
      create(storage, other)
        ..value = null
        ..value = sample;
      expect(create(storage, other).value, sample);
    });
  });
}

const _failOnEvent = _FailingObserver();

final class _FailingObserver extends SettingsObserver {
  const _FailingObserver();

  @override
  void onEvent(SettingsEvent event) => fail('unexpected diagnostic: $event');
}

void main() {
  settingContract<bool>(
    'BoolSetting',
    create: (s) => BoolSetting(storage: s, key: 'k', defaultValue: false),
    defaultValue: false,
    sample: true,
    other: false,
  );
  nullableSettingContract<bool>(
    'BoolNullableSetting',
    create: (s, d) => BoolNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: true,
    other: false,
  );

  settingContract<int>(
    'IntSetting',
    create: (s) => IntSetting(storage: s, key: 'k', defaultValue: 0),
    defaultValue: 0,
    sample: 42,
    other: -7,
  );
  nullableSettingContract<int>(
    'IntNullableSetting',
    create: (s, d) => IntNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: 42,
    other: -7,
  );

  settingContract<double>(
    'DoubleSetting',
    create: (s) => DoubleSetting(storage: s, key: 'k', defaultValue: 0),
    defaultValue: 0,
    sample: 1.5,
    other: -2.25,
  );
  nullableSettingContract<double>(
    'DoubleNullableSetting',
    create: (s, d) => DoubleNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: 1.5,
    other: -2.25,
  );

  settingContract<String>(
    'StringSetting',
    create: (s) => StringSetting(storage: s, key: 'k', defaultValue: ''),
    defaultValue: '',
    sample: 'hello',
    other: 'world',
  );
  nullableSettingContract<String>(
    'StringNullableSetting',
    create: (s, d) => StringNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: 'hello',
    other: 'world',
  );

  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final someDay = DateTime.fromMillisecondsSinceEpoch(1700000000123);
  final otherDay = DateTime.fromMillisecondsSinceEpoch(1600000000000);
  settingContract<DateTime>(
    'DateTimeSetting',
    create: (s) => DateTimeSetting(storage: s, key: 'k', defaultValue: epoch),
    defaultValue: epoch,
    sample: someDay,
    other: otherDay,
  );
  nullableSettingContract<DateTime>(
    'DateTimeNullableSetting',
    create: (s, d) => DateTimeNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: someDay,
    other: otherDay,
  );

  settingContract<Duration>(
    'DurationSetting',
    create: (s) => DurationSetting(storage: s, key: 'k', defaultValue: Duration.zero),
    defaultValue: Duration.zero,
    sample: const Duration(minutes: 3, milliseconds: 4),
    other: const Duration(hours: 1),
  );
  nullableSettingContract<Duration>(
    'DurationNullableSetting',
    create: (s, d) => DurationNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: const Duration(minutes: 3, milliseconds: 4),
    other: const Duration(hours: 1),
  );

  settingContract<Level>(
    'EnumSetting',
    create: (s) => EnumSetting(storage: s, key: 'k', defaultValue: Level.low, values: Level.values),
    defaultValue: Level.low,
    sample: Level.high,
    other: Level.mid,
  );
  nullableSettingContract<Level>(
    'EnumNullableSetting',
    create: (s, d) => EnumNullableSetting(storage: s, key: 'k', defaultValue: d, values: Level.values),
    sample: Level.high,
    other: Level.mid,
  );

  final home = Uri.parse('https://example.com/');
  final docs = Uri.parse('https://example.com/docs?page=2#top');
  final mail = Uri.parse('mailto:a@b.c');
  settingContract<Uri>(
    'UriSetting',
    create: (s) => UriSetting(storage: s, key: 'k', defaultValue: home),
    defaultValue: home,
    sample: docs,
    other: mail,
  );
  nullableSettingContract<Uri>(
    'UriNullableSetting',
    create: (s, d) => UriNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: docs,
    other: mail,
  );

  settingContract<List<int>>(
    'IntListSetting',
    create: (s) => IntListSetting(storage: s, key: 'k', defaultValue: const []),
    defaultValue: const [],
    sample: const [1, 2, 3],
    other: const [9],
  );
  settingContract<List<String>>(
    'StringListSetting',
    create: (s) => StringListSetting(storage: s, key: 'k', defaultValue: const []),
    defaultValue: const [],
    sample: const ['a', 'b'],
    other: const ['z'],
  );
  nullableSettingContract<List<int>>(
    'IntListNullableSetting',
    create: (s, d) => IntListNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: const [1, 2, 3],
    other: const [9],
  );
  nullableSettingContract<List<String>>(
    'StringListNullableSetting',
    create: (s, d) => StringListNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: const ['a', 'b'],
    other: const ['z'],
  );
  nullableSettingContract<List<int>>(
    'ListNullableSetting',
    create: (s, d) => ListNullableSetting<int>(
      storage: s,
      key: 'k',
      defaultValue: d,
      fromJson: (e) => e! as int,
      toJson: (e) => e,
    ),
    sample: const [1, 2, 3],
    other: const [9],
  );

  settingContract<Map<String, Object?>>(
    'MapSetting',
    create: (s) => MapSetting(storage: s, key: 'k', defaultValue: const {}),
    defaultValue: const {},
    sample: const {
      'a': 1,
      'nested': {
        'list': [true, null, 'x'],
      },
    },
    other: const {'b': 2.5},
  );
  nullableSettingContract<Map<String, Object?>>(
    'MapNullableSetting',
    create: (s, d) => MapNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: const {
      'a': 1,
      'nested': {
        'list': [true, null, 'x'],
      },
    },
    other: const {'b': 2.5},
  );

  settingContract<Point>(
    'JsonSetting',
    create: (s) => JsonSetting(
      storage: s,
      key: 'k',
      defaultValue: const Point(0, 0),
      fromJson: Point.fromJson,
      toJson: (p) => p.toJson(),
    ),
    defaultValue: const Point(0, 0),
    sample: const Point(1, 2),
    other: const Point(-3, 4),
  );
  nullableSettingContract<Point>(
    'JsonNullableSetting',
    create: (s, d) =>
        JsonNullableSetting(storage: s, key: 'k', defaultValue: d, fromJson: Point.fromJson, toJson: (p) => p.toJson()),
    sample: const Point(1, 2),
    other: const Point(-3, 4),
  );

  settingContract<Set<Level>>(
    'EnumSetSetting',
    create: (s) => EnumSetSetting(storage: s, key: 'k', defaultValue: const {}, values: Level.values),
    defaultValue: const {},
    sample: const {Level.high, Level.low},
    other: const {Level.mid},
  );
  nullableSettingContract<Set<Level>>(
    'EnumSetNullableSetting',
    create: (s, d) => EnumSetNullableSetting(storage: s, key: 'k', defaultValue: d, values: Level.values),
    sample: const {Level.high, Level.low},
    other: const {Level.mid},
  );
  settingContract<Set<String>>(
    'StringSetSetting',
    create: (s) => StringSetSetting(storage: s, key: 'k', defaultValue: const {}),
    defaultValue: const {},
    sample: const {'a', 'b'},
    other: const {'z'},
  );
  nullableSettingContract<Set<String>>(
    'StringSetNullableSetting',
    create: (s, d) => StringSetNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: const {'a', 'b'},
    other: const {'z'},
  );

  final firstDay = DateTime(2000);
  final birthday = DateTime(1990, 7, 15);
  final leapDay = DateTime(2024, 2, 29);
  settingContract<DateTime>(
    'DateSetting',
    create: (s) => DateSetting(storage: s, key: 'k', defaultValue: firstDay),
    defaultValue: firstDay,
    sample: birthday,
    other: leapDay,
  );
  nullableSettingContract<DateTime>(
    'DateNullableSetting',
    create: (s, d) => DateNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: birthday,
    other: leapDay,
  );

  final noBytes = Uint8List(0);
  final key = Uint8List.fromList([0, 1, 254, 255]);
  final salt = Uint8List.fromList([42]);
  settingContract<Uint8List>(
    'BytesSetting',
    create: (s) => BytesSetting(storage: s, key: 'k', defaultValue: noBytes),
    defaultValue: noBytes,
    sample: key,
    other: salt,
  );
  nullableSettingContract<Uint8List>(
    'BytesNullableSetting',
    create: (s, d) => BytesNullableSetting(storage: s, key: 'k', defaultValue: d),
    sample: key,
    other: salt,
  );

  const oneToTen = ValueRange<int>(start: 1, end: 10);
  const zeroToHundred = ValueRange<int>(start: 0, end: 100);
  const five = ValueRange<int>(start: 5, end: 5);
  settingContract<ValueRange<int>>(
    'RangeSetting.ofInt',
    create: (s) => RangeSetting.ofInt(storage: s, key: 'k', defaultValue: oneToTen),
    defaultValue: oneToTen,
    sample: zeroToHundred,
    other: five,
  );
  nullableSettingContract<ValueRange<int>>(
    'RangeNullableSetting.ofInt',
    create: (s, d) => RangeNullableSetting.ofInt(storage: s, key: 'k', defaultValue: d),
    sample: zeroToHundred,
    other: five,
  );

  const halfToOne = ValueRange<double>(start: 0.5, end: 1.5);
  const twoToThree = ValueRange<double>(start: 2, end: 3);
  const zero = ValueRange<double>(start: 0, end: 0);
  settingContract<ValueRange<double>>(
    'RangeSetting.ofDouble',
    create: (s) => RangeSetting.ofDouble(storage: s, key: 'k', defaultValue: halfToOne),
    defaultValue: halfToOne,
    sample: twoToThree,
    other: zero,
  );
  nullableSettingContract<ValueRange<double>>(
    'RangeNullableSetting.ofDouble',
    create: (s, d) => RangeNullableSetting.ofDouble(storage: s, key: 'k', defaultValue: d),
    sample: twoToThree,
    other: zero,
  );

  const secondToMinute = ValueRange<Duration>(start: Duration(seconds: 1), end: Duration(minutes: 1));
  const hour = ValueRange<Duration>(start: Duration.zero, end: Duration(hours: 1));
  const none = ValueRange<Duration>(start: Duration.zero, end: Duration.zero);
  settingContract<ValueRange<Duration>>(
    'RangeSetting.ofDuration',
    create: (s) => RangeSetting.ofDuration(storage: s, key: 'k', defaultValue: secondToMinute),
    defaultValue: secondToMinute,
    sample: hour,
    other: none,
  );
  nullableSettingContract<ValueRange<Duration>>(
    'RangeNullableSetting.ofDuration',
    create: (s, d) => RangeNullableSetting.ofDuration(storage: s, key: 'k', defaultValue: d),
    sample: hour,
    other: none,
  );

  final january = ValueRange<DateTime>(start: DateTime(2020), end: DateTime(2020, 1, 31));
  final summer = ValueRange<DateTime>(start: DateTime(2020, 6), end: DateTime(2020, 8, 31));
  final newYear = ValueRange<DateTime>(start: DateTime(2021), end: DateTime(2021));
  settingContract<ValueRange<DateTime>>(
    'RangeSetting.ofDateTime',
    create: (s) => RangeSetting.ofDateTime(storage: s, key: 'k', defaultValue: january),
    defaultValue: january,
    sample: summer,
    other: newYear,
  );
  nullableSettingContract<ValueRange<DateTime>>(
    'RangeNullableSetting.ofDateTime',
    create: (s, d) => RangeNullableSetting.ofDateTime(storage: s, key: 'k', defaultValue: d),
    sample: summer,
    other: newYear,
  );
}

/// A model class with the `fromJson` / `toJson` pair json_serializable
/// generates.
@immutable
final class Point {
  const Point(this.x, this.y);

  factory Point.fromJson(Map<String, dynamic> json) => Point(json['x'] as int, json['y'] as int);

  final int x;
  final int y;

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)';
}
