import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const supported = [Locale('en'), Locale('ru'), Locale('de')];

  late InMemoryStorage storage;
  late LocaleNullableSetting setting;
  late AppliedLocale applied;

  setUp(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.localesTestValue = const [Locale('ru')];
    storage = InMemoryStorage();
    setting = LocaleNullableSetting(storage: storage, key: 'locale');
    applied = AppliedLocale(setting: setting, supportedLocales: supported);
  });

  tearDown(() {
    applied.dispose();
    setting.dispose();
    TestWidgetsFlutterBinding.instance.platformDispatcher.clearLocalesTestValue();
  });

  test('value is the chosen locale', () {
    setting.value = const Locale('de');

    expect(applied.value, const Locale('de'));
    expect(applied.setting, same(setting));
  });

  test('a null choice resolves to a supported locale of the device', () {
    expect(setting.value, isNull);
    expect(applied.value, const Locale('ru'));
  });

  test('a device language change notifies while the choice follows the device', () {
    final seen = <Locale>[];
    applied.addListener(() => seen.add(applied.value));

    TestWidgetsFlutterBinding.instance.platformDispatcher.localesTestValue = const [Locale('de')];

    expect(seen, [const Locale('de')]);
    expect(applied.setting.value, isNull);
  });

  test('a device language change while a locale is chosen is kept for the return to the device', () {
    setting.value = const Locale('en');
    var notifications = 0;
    applied.addListener(() => notifications++);

    TestWidgetsFlutterBinding.instance.platformDispatcher.localesTestValue = const [Locale('de')];

    expect(notifications, 0);
    expect(applied.value, const Locale('en'));

    setting.value = null;

    expect(notifications, 1);
    expect(applied.value, const Locale('de'));
  });

  test('dispose drops the device subscription and leaves the setting usable', () {
    var notifications = 0;
    applied.addListener(() => notifications++);

    applied.dispose();
    TestWidgetsFlutterBinding.instance.platformDispatcher.localesTestValue = const [Locale('de')];
    setting.value = const Locale('en');

    expect(notifications, 0);
    expect(setting.value, const Locale('en'));
    expect(applied.value, const Locale('en'));
  });

  test('a ValueNotifier is a valid source', () {
    final choice = ValueNotifier<Locale?>(null);
    addTearDown(choice.dispose);
    final fromNotifier = AppliedLocale(setting: choice, supportedLocales: supported);
    addTearDown(fromNotifier.dispose);

    expect(fromNotifier.value, const Locale('ru'));
    expect(choice.value, isNull);

    choice.value = const Locale('de');

    expect(fromNotifier.value, const Locale('de'));
  });

  test('an empty list of translations is an ArgumentError', () {
    expect(
      () => AppliedLocale(setting: setting, supportedLocales: const []),
      throwsArgumentError,
    );
  });
}
