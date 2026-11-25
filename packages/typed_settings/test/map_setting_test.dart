import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

import 'package:typed_settings_conformance/typed_settings_conformance.dart';

void main() {
  group('MapSetting equality', () {
    test('assigning a deeply equal map does not rewrite or notify', () {
      final storage = InMemoryStorage();
      final setting = MapSetting(storage: storage, key: 'm', defaultValue: {});
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = {
        'a': 1,
        'nested': {
          'b': [1, 2],
        },
      };
      expect(notifications, 1);

      // Equal by content, different instance.
      setting.value = {
        'a': 1,
        'nested': {
          'b': [1, 2],
        },
      };
      expect(notifications, 1, reason: 'deep-equal value must be deduplicated');
    });

    test('isDefault uses deep equality', () {
      final storage = InMemoryStorage();
      final setting = MapSetting(storage: storage, key: 'm', defaultValue: {'a': 1});
      expect(setting.isDefault, isTrue);
    });
  });

  group('MapSetting value isolation', () {
    test('the value read from the setting is unmodifiable, including nested collections', () {
      final storage = InMemoryStorage()..setString('m', '{"a":1,"nested":{"list":[1,2]}}');
      final setting = MapSetting(storage: storage, key: 'm', defaultValue: const {});

      final read = setting.value;
      expect(() => read['a'] = 2, throwsUnsupportedError);
      expect(() => (read['nested']! as Map)['b'] = 2, throwsUnsupportedError);
      expect(() => ((read['nested']! as Map)['list'] as List).add(3), throwsUnsupportedError);
      expect(storage.getString('m'), '{"a":1,"nested":{"list":[1,2]}}', reason: 'storage state must stay intact');
    });

    test('is stored as a JSON object string and rejects non-object JSON on read', () {
      final observer = RecordingObserver();
      final storage = InMemoryStorage(observer: observer)..setString('m', '[1, 2]');
      final setting = MapSetting(storage: storage, key: 'm', defaultValue: const {'d': 1});

      expect(setting.value, {'d': 1}, reason: 'a JSON array is not a map');
      expect(observer.events.single, isA<DecodeFallbackEvent>());

      setting.value = {'a': 1};
      expect(storage.getString('m'), '{"a":1}');
    });

    test('mutating the map passed to the setter afterwards affects neither cache nor storage', () {
      final storage = InMemoryStorage();
      final setting = MapSetting(storage: storage, key: 'm', defaultValue: const {});
      final assigned = {
        'a': 1,
        'nested': {'b': 1},
      };

      setting.value = assigned;
      assigned['a'] = 999;
      (assigned['nested']! as Map)['b'] = 999;

      expect(setting.value['a'], 1);
      expect((setting.value['nested']! as Map)['b'], 1);
      expect(storage.getString('m'), '{"a":1,"nested":{"b":1}}');
    });

    test('the default value cannot be mutated through the setting', () {
      final storage = InMemoryStorage();
      final defaultValue = <String, Object?>{'a': 1};
      final setting = MapSetting(storage: storage, key: 'm', defaultValue: defaultValue);

      expect(() => setting.value['a'] = 2, throwsUnsupportedError);
      expect(defaultValue, {'a': 1});
    });
  });

  group('MapNullableSetting', () {
    test('null assignment removes the stored value', () {
      final storage = InMemoryStorage();
      final setting = MapNullableSetting(storage: storage, key: 'm');

      setting.value = {'a': 1};
      expect(storage.getString('m'), '{"a":1}');

      setting.value = null;
      expect(storage.getString('m'), isNull);
      expect(storage.hasNull('m'), isTrue);
      expect(setting.value, isNull);
    });

    test('deduplicates deep-equal values', () {
      final storage = InMemoryStorage();
      final setting = MapNullableSetting(storage: storage, key: 'm');
      var notifications = 0;
      setting.addListener(() => notifications++);

      setting.value = {'a': 1};
      setting.value = {'a': 1};
      expect(notifications, 1);
    });
  });
}
