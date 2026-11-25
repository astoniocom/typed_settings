// The example reports what happens on the console.
// ignore_for_file: avoid_print

import 'package:flutter/widgets.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_shared_preferences/typed_settings_shared_preferences.dart';

Future<void> main() async {
  // The plugin is reached through the binding, which runApp would
  // otherwise set up.
  WidgetsFlutterBinding.ensureInitialized();

  final storage = await SharedPreferencesStorage.create(box: 'settings');
  final launchCount = IntSetting(storage: storage, key: 'launch_count', defaultValue: 0);

  launchCount.value++;
  print('launched ${launchCount.value} times');

  // Writes reach the platform in the background; flush waits for them.
  await storage.flush();
}
