// The example reports what happens on the console.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_hive/typed_settings_hive.dart';

Future<void> main() async {
  // A Flutter application calls `Hive.initFlutter()` of hive_ce_flutter
  // instead.
  final directory = Directory.systemTemp.createTempSync('typed_settings_hive_example');
  Hive.init(directory.path);

  var storage = await HiveStorage.create(box: 'settings');
  IntSetting(storage: storage, key: 'launch_count', defaultValue: 0).value++;
  await storage.close();

  storage = await HiveStorage.create(box: 'settings');
  final launchCount = IntSetting(storage: storage, key: 'launch_count', defaultValue: 0);
  print('launch count after reopening the box: ${launchCount.value}');
  await storage.close();

  directory.deleteSync(recursive: true);
}
