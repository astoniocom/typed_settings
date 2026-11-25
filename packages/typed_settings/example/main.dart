// The example reports what happens on the console.
// ignore_for_file: avoid_print

import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

enum ThemeChoice { light, dark, system }

/// The settings of an application over one storage.
class AppSettings {
  AppSettings(SettingsStorage storage)
    : volume = IntSetting(
        storage: storage,
        key: 'volume',
        defaultValue: 50,
        validator: SettingValidator.range(min: 0, max: 100),
      ),
      theme = EnumSetting(storage: storage, key: 'theme', values: ThemeChoice.values, defaultValue: ThemeChoice.system);

  final IntSetting volume;
  final EnumSetting<ThemeChoice> theme;
}

Future<void> main() async {
  // A backend package (Hive, SharedPreferences, ...) gives a persistent
  // storage; the settings are declared the same way over any of them.
  final storage = InMemoryStorage();
  final settings = AppSettings(storage);

  settings.volume.addListener(() => print('volume is now ${settings.volume.value}'));

  print('volume: ${settings.volume.value}, theme: ${settings.theme.value.name}');
  settings.volume.value = 80;
  settings.theme.value = ThemeChoice.dark;

  try {
    settings.volume.value = 150;
  } on SettingValidationException catch (e) {
    if (e.error case RangeValidationError(:final actual, :final min, :final max)) {
      print('rejected: $actual is outside $min..$max');
    }
  }

  settings.volume.reset();
  print('volume after reset: ${settings.volume.value}');

  await storage.close();
}
