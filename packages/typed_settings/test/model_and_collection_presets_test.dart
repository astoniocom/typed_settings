import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

enum _Channel { news, offers, security }

/// A model class without `==` of its own.
final class _Filter {
  _Filter(this.query, this.limit);

  factory _Filter.fromJson(Map<String, dynamic> json) => _Filter(json['query'] as String, json['limit'] as int);

  final String query;
  final int limit;

  Map<String, dynamic> toJson() => {'query': query, 'limit': limit};
}

final class _CountingStorage extends InMemoryStorage {
  _CountingStorage({super.observer});

  int setStringCalls = 0;

  @override
  void setString(String key, String value) {
    setStringCalls++;
    super.setString(key, value);
  }
}

void main() {
  late RecordingObserver observer;
  late _CountingStorage storage;

  setUp(() {
    observer = RecordingObserver();
    storage = _CountingStorage(observer: observer);
  });

  group('JsonSetting', () {
    JsonSetting<_Filter> filterSetting() => JsonSetting(
      storage: storage,
      key: 'filter',
      defaultValue: _Filter('', 10),
      fromJson: _Filter.fromJson,
      toJson: (filter) => filter.toJson(),
    );

    test('stores the model as a JSON object', () {
      filterSetting().value = _Filter('cats', 5);

      expect(storage.getString('filter'), '{"query":"cats","limit":5}');
      final reread = filterSetting().value;
      expect([reread.query, reread.limit], ['cats', 5]);
    });

    test('compares values by their JSON, so a class without == is not written again', () {
      final setting = filterSetting()..value = _Filter('cats', 5);
      final writes = storage.setStringCalls;
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = _Filter('cats', 5);

      expect(storage.setStringCalls, writes);
      expect(notifications, 0);
      expect(setting.isDefault, isFalse);
      expect(filterSetting().isDefault, isFalse);
      expect(
        JsonSetting(
          storage: InMemoryStorage(),
          key: 'filter',
          defaultValue: _Filter('', 10),
          fromJson: _Filter.fromJson,
          toJson: (filter) => filter.toJson(),
        ).isDefault,
        isTrue,
        reason: 'the default equals itself as stored',
      );
    });

    test('falls back to the default for JSON that is not an object, and reports it', () {
      storage.setString('filter', '[1]');

      expect(filterSetting().value.query, '');
      expect(observer.events.single, isA<DecodeFallbackEvent>());
    });
  });

  group('EnumSetSetting', () {
    EnumSetSetting<_Channel> channels({Map<String, _Channel> legacyNames = const {}}) => EnumSetSetting(
      storage: storage,
      key: 'channels',
      defaultValue: const {_Channel.security},
      values: _Channel.values,
      legacyNames: legacyNames,
    );

    test('stores the names of the constants', () {
      channels().value = {_Channel.offers, _Channel.news};

      expect(storage.getString('channels'), '["offers","news"]');
    });

    test('reads legacy names', () {
      storage.setString('channels', '["promotions"]');

      expect(channels(legacyNames: const {'promotions': _Channel.offers}).value, {_Channel.offers});
    });

    test('an unknown name makes the stored set fall back to the default, and the set stays stored', () {
      storage.setString('channels', '["news","beta"]');
      final setting = channels();

      expect(setting.value, {_Channel.security});
      expect(observer.events.single, isA<DecodeFallbackEvent>());

      setting.value = {_Channel.security};
      expect(storage.getString('channels'), '["news","beta"]', reason: 'writing the default it shows keeps it');
    });

    test('rejects a default with a constant outside values', () {
      expect(
        () => EnumSetSetting(
          storage: storage,
          key: 'channels',
          defaultValue: const {_Channel.security},
          values: const [_Channel.news],
        ),
        throwsArgumentError,
      );
      expect(SettingsRegistry.of(storage).settings, isEmpty, reason: 'the rejected setting registered nothing');
    });

    test('is unmodifiable, and the same elements in another order are not written again', () {
      final setting = channels()..value = {_Channel.news, _Channel.offers};
      final writes = storage.setStringCalls;

      setting.value = {_Channel.offers, _Channel.news};

      expect(storage.setStringCalls, writes);
      expect(() => setting.value.add(_Channel.security), throwsUnsupportedError);
    });
  });

  test('StringSetSetting falls back for an element that is not a string', () {
    storage.setString('tags', '["a",1]');

    expect(StringSetSetting(storage: storage, key: 'tags', defaultValue: const {'x'}).value, {'x'});
    expect(observer.events.single, isA<DecodeFallbackEvent>());
  });

  group('DateSetting', () {
    test('drops the time of day at once and stores the date', () {
      final setting = DateSetting(storage: storage, key: 'due', defaultValue: DateTime(2000))
        ..value = DateTime(2024, 5, 17, 18, 30);

      expect(setting.value, DateTime(2024, 5, 17));
      expect(storage.getString('due'), '2024-05-17');
    });
  });

  group('BytesSetting', () {
    test('copies assigned bytes and hands out an unmodifiable view', () {
      final buffer = Uint8List.fromList([1, 2, 3]);
      final setting = BytesSetting(storage: storage, key: 'salt', defaultValue: Uint8List(0))..value = buffer;

      buffer[0] = 9;

      expect(setting.value, [1, 2, 3]);
      expect(() => setting.value[0] = 9, throwsUnsupportedError);
      expect(storage.getString('salt'), 'AQID');
    });
  });
}
