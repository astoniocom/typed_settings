import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:test/test.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';
import 'package:typed_settings_hive/typed_settings_hive.dart';

void main() {
  late Directory dir;
  var boxCounter = 0;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('typed_settings_hive_test');
    Hive.init(dir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  storageConformance('HiveStorage', (observer) async {
    final box = await Hive.openBox<dynamic>('conformance_${boxCounter++}');
    return HiveStorage(box: box, observer: observer);
  });
  storageConformance('HiveStorage with a persistence delay', (observer) async {
    final box = await Hive.openBox<dynamic>('conformance_delay_${boxCounter++}');
    return HiveStorage(box: box, observer: observer, persistenceDelay: const Duration(hours: 1));
  });

  test('one open storage per box, until it is closed, which closes the box', () async {
    final box = await Hive.openBox<dynamic>('lifecycle');
    final storage = HiveStorage(box: box)..setInt('k', 1);

    expect(() => HiveStorage(box: box), throwsStateError);
    await expectLater(HiveStorage.create(box: 'lifecycle'), throwsStateError, reason: 'Hive hands out the open box');

    await storage.close();

    expect(box.isOpen, isFalse);
    final reopened = await HiveStorage.create(box: 'lifecycle');
    expect(reopened.getInt('k'), 1);
    await reopened.close();
  });

  test('a persistence delay keeps the latest value in front of the box until flush', () async {
    final box = await Hive.openBox<dynamic>('delay_${boxCounter++}');
    final storage = HiveStorage(box: box, persistenceDelay: const Duration(seconds: 30));
    storage
      ..setInt('k', 1)
      ..setInt('k', 2);

    expect(storage.getInt('k'), 2);
    expect(box.get('k'), isNull, reason: 'the box is written when the delay passes or a flush starts it');

    await storage.flush();

    expect(box.get('k'), 2);
    expect(storage.getInt('k'), 2);
    await storage.close();
  });

  test('a removal that finishes after a newer write of the key does not hide that write', () async {
    final box = await Hive.openBox<dynamic>('late_removal_${boxCounter++}');
    final storage = HiveStorage(box: box, persistenceDelay: const Duration(seconds: 30));
    final cleared = storage.clear();
    storage.remove('k');
    await cleared;
    final removed = storage.flush();
    storage.setInt('k', 5);

    await removed;

    expect(storage.getInt('k'), 5);
    await storage.flush();
    expect(box.get('k'), 5);
    await storage.close();
  });

  test('clear with a delay drops a write still held and keeps a write made after it', () async {
    final box = await Hive.openBox<dynamic>('clear_delay_${boxCounter++}');
    final storage = HiveStorage(box: box, persistenceDelay: const Duration(seconds: 30))
      ..setInt('k', 1)
      ..setInt('kept', 2);
    await storage.flush();
    storage.setInt('k', 3);

    await storage.clear();

    expect(storage.keys, isEmpty);
    expect(box.get('k'), isNull);
    expect(box.get('kept'), isNull);

    storage.setInt('after', 4);
    await storage.flush();

    expect(box.get('after'), 4);
    expect(storage.getInt('k'), isNull);
    await storage.close();
  });
}
