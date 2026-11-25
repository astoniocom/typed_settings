import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_flutter/typed_settings_flutter_extend.dart';

void main() {
  late InMemoryStorage storage;
  late _RecordingErrorHandler handler;

  setUp(() {
    storage = InMemoryStorage();
    handler = _RecordingErrorHandler();
  });

  Future<void> pumpTile(WidgetTester tester, Widget tile) => tester.pumpWidget(
    MaterialApp(
      home: SettingsErrorHandlerProvider(
        handler: handler,
        child: Scaffold(body: ListView(children: [tile])),
      ),
    ),
  );

  SettingValidator<T> forbid<T>(T forbidden) => SettingValidator(
    (value) => value == forbidden ? ForbiddenValueValidationError(value, debugDescription: 'forbidden') : null,
  );

  testWidgets('EnumSettingTile stores the picked value and reports a rejected one', (tester) async {
    final setting = EnumSetting(
      storage: storage,
      key: 'k',
      values: ThemeMode.values,
      defaultValue: ThemeMode.light,
      validator: forbid(ThemeMode.dark),
    );
    await pumpTile(tester, EnumSettingTile(setting: setting, label: 'Mode'));

    await tester.tap(find.text('Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('system').last);
    await tester.pumpAndSettle();
    expect(setting.value, ThemeMode.system);

    await tester.tap(find.text('Mode'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('dark').last);
    await tester.pumpAndSettle();
    expect(setting.value, ThemeMode.system);
    expect(handler.reports.single.settingName, 'Mode');
  });

  testWidgets('EnumSettingTile keeps its menu across rebuilds of the parent', (tester) async {
    final setting = EnumSetting(storage: storage, key: 'k', values: ThemeMode.values, defaultValue: ThemeMode.light);
    await pumpTile(tester, EnumSettingTile(setting: setting, label: 'Mode'));
    await tester.tap(find.text('Mode'));
    await tester.pumpAndSettle();

    await pumpTile(tester, EnumSettingTile(setting: setting, label: 'Mode'));
    await tester.pumpAndSettle();

    expect(find.text('system'), findsOneWidget);
  });

  testWidgets('ThemeSettingTile stores a ThemeMode', (tester) async {
    final setting = EnumSetting(storage: storage, key: 'k', values: ThemeMode.values, defaultValue: ThemeMode.system);
    await pumpTile(tester, ThemeSettingTile(setting: setting, label: 'Theme'));

    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pumpAndSettle();

    expect(setting.value, ThemeMode.dark);
    expect(storage.getString('k'), 'dark');
  });

  testWidgets('a long value ellipsizes and leaves the title its room', (tester) async {
    final setting = StringSetting(storage: storage, key: 'k', defaultValue: 'https://example.com/' * 10);
    await pumpTile(tester, StringSettingTile(setting: setting, label: 'Server URL'));

    expect(tester.takeException(), isNull);
    final row = tester.getSize(find.byType(ListTile)).width;
    expect(tester.getSize(find.text('Server URL')).width, greaterThan(0));
    expect(tester.getSize(find.byType(ValueChip)).width, lessThanOrEqualTo(row / 2));
  });

  testWidgets('a long enum name ellipsizes inside its menu button', (tester) async {
    final setting = EnumSetting(storage: storage, key: 'k', values: ThemeMode.values, defaultValue: ThemeMode.light);
    await pumpTile(
      tester,
      EnumSettingTile(setting: setting, label: 'Mode', nameBuilder: (mode) => '${mode.name} ' * 40),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the theme segments fit a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final setting = EnumSetting(storage: storage, key: 'k', values: ThemeMode.values, defaultValue: ThemeMode.system);
    await pumpTile(tester, ThemeSettingTile(setting: setting, label: 'Theme'));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a date and time follow the device 24-hour setting, as the pickers do', (tester) async {
    final setting = DateTimeSetting(storage: storage, key: 'k', defaultValue: DateTime(2026, 1, 5, 14, 30));
    Future<void> pump({required bool use24Hour}) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(alwaysUse24HourFormat: use24Hour),
          child: Scaffold(
            body: DateTimeSettingTile(setting: setting, label: 'When'),
          ),
        ),
      ),
    );

    await pump(use24Hour: false);
    expect(find.text('01/05/2026 2:30 PM'), findsOneWidget);

    await pump(use24Hour: true);
    expect(find.text('01/05/2026 14:30'), findsOneWidget);
  });

  testWidgets('a double uses the decimal separator of the locale', (tester) async {
    final setting = DoubleSetting(storage: storage, key: 'k', defaultValue: 0.5);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        supportedLocales: const [Locale('de')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: DoubleSettingTile(setting: setting, label: 'Volume'),
        ),
      ),
    );

    expect(find.text('0,50'), findsOneWidget);
  });

  testWidgets('TimeOfDaySettingTile shows the time as the picker does', (tester) async {
    final setting = TimeOfDaySetting(
      storage: storage,
      key: 'k',
      defaultValue: const TimeOfDay(hour: 21, minute: 5),
    );
    await pumpTile(tester, TimeOfDaySettingTile(setting: setting, label: 'Quiet hours'));

    expect(find.text('9:05 PM'), findsOneWidget);
  });

  testWidgets('TimeOfDayNullableSettingTile clears a time from the picker', (tester) async {
    final setting = TimeOfDayNullableSetting(
      storage: storage,
      key: 'k',
      defaultValue: const TimeOfDay(hour: 7, minute: 0),
    );
    await pumpTile(tester, TimeOfDayNullableSettingTile(setting: setting, label: 'Alarm'));

    await tester.tap(find.text('Alarm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear value'));
    await tester.pumpAndSettle();

    expect(setting.value, isNull);
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });

  testWidgets('DateTimeNullableSettingTile clears from the date picker', (tester) async {
    final setting = DateTimeNullableSetting(
      storage: storage,
      key: 'k',
      defaultValue: DateTime(2020, 6, 15, 14, 30),
    );
    await pumpTile(tester, DateTimeNullableSettingTile(setting: setting, label: 'When'));

    await tester.tap(find.text('When'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear value'));
    await tester.pumpAndSettle();

    expect(setting.value, isNull);
    expect(find.byType(DatePickerDialog), findsNothing);
  });

  testWidgets('DateTimeNullableSettingTile clears from the time picker instead of keeping the date', (tester) async {
    final setting = DateTimeNullableSetting(
      storage: storage,
      key: 'k',
      defaultValue: DateTime(2020, 6, 15, 14, 30),
    );
    await pumpTile(tester, DateTimeNullableSettingTile(setting: setting, label: 'When'));

    await tester.tap(find.text('When'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Clear value'));
    await tester.pumpAndSettle();

    expect(setting.value, isNull);
    expect(find.byType(TimePickerDialog), findsNothing);
  });

  testWidgets('LocaleSettingTile picks a locale and names it', (tester) async {
    final setting = LocaleSetting(storage: storage, key: 'k', defaultValue: const Locale('en'));
    const names = {'en': 'English', 'de': 'Deutsch'};
    await pumpTile(
      tester,
      LocaleSettingTile(
        setting: setting,
        label: 'Language',
        locales: const [Locale('en'), Locale('de')],
        nameBuilder: (locale) => names[locale.languageCode]!,
      ),
    );

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch').last);
    await tester.pumpAndSettle();

    expect(setting.value, const Locale('de'));
    expect(find.text('Deutsch'), findsOneWidget);
  });

  testWidgets('LocaleNullableSettingTile stores null, the "follow the device" choice', (tester) async {
    final setting = LocaleNullableSetting(storage: storage, key: 'k', defaultValue: const Locale('en'));
    await pumpTile(
      tester,
      LocaleNullableSettingTile(
        setting: setting,
        label: 'Language',
        locales: const [Locale('en')],
        nullLabel: 'System language',
      ),
    );

    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('System language').last);
    await tester.pumpAndSettle();

    expect(setting.value, isNull);
    expect(find.text('System language'), findsOneWidget);
  });

  testWidgets('MapTile edits a ValueNotifier without a Setting', (tester) async {
    final notifier = ValueNotifier<Map<String, Object?>>({});
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MapTile(notifier: notifier, label: 'Extras'),
        ),
      ),
    );

    await tester.tap(find.text('Extras'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{"a": 1}');
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(notifier.value, {'a': 1});
  });

  testWidgets('a color swatch is a focusable button a screen reader names', (tester) async {
    final semantics = tester.ensureSemantics();
    final setting = ColorSetting(storage: storage, key: 'k', defaultValue: const Color(0xFF2196F3));
    await pumpTile(tester, ColorSettingTile(setting: setting, label: 'Accent', presets: const [Color(0xFFF44336)]));

    expect(find.bySemanticsLabel('#FF2196F3'), findsOneWidget);

    await tester.tap(find.text('Accent'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('#FFF44336')),
      isSemantics(isButton: true, isFocusable: true),
    );
    semantics.dispose();
  });

  testWidgets('ThemeSettingTile names each theme mode and accepts other names', (tester) async {
    final setting = EnumSetting(storage: storage, key: 'k', values: ThemeMode.values, defaultValue: ThemeMode.system);
    await pumpTile(tester, ThemeSettingTile(setting: setting, label: 'Theme'));
    final semantics = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel('Light'), findsOneWidget);
      expect(find.bySemanticsLabel('System'), findsOneWidget);
      expect(find.bySemanticsLabel('Dark'), findsOneWidget);
      expect(
        tester.getSemantics(find.byTooltip('System')),
        isSemantics(tooltip: 'System', isSelected: true, isInMutuallyExclusiveGroup: true),
      );
      expect(tester.getSemantics(find.byTooltip('Light')), isSemantics(tooltip: 'Light', isSelected: false));

      await pumpTile(
        tester,
        ThemeSettingTile(
          setting: setting,
          label: 'Theme',
          lightLabel: 'Day',
          systemLabel: 'Auto',
          darkLabel: 'Night',
        ),
      );

      expect(find.bySemanticsLabel('Day'), findsOneWidget);
      expect(find.bySemanticsLabel('Auto'), findsOneWidget);
      expect(find.bySemanticsLabel('Night'), findsOneWidget);
      expect(find.byTooltip('Day'), findsOneWidget);
      expect(find.bySemanticsLabel('Light'), findsNothing);
      expect(find.byTooltip('Light'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('ColorSettingTile keeps a stored color that is not a preset and accepts a hex color', (tester) async {
    const custom = Color(0xFF112233);
    final setting = ColorSetting(storage: storage, key: 'k', defaultValue: custom);
    await pumpTile(tester, ColorSettingTile(setting: setting, label: 'Tint', presets: const [Colors.red]));

    await tester.tap(find.text('Tint'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '#FF112233');
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.enterText(find.byType(TextField), '#00FF00');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();

    expect(setting.value, const Color(0xFF00FF00));
  });

  testWidgets('ColorNullableSettingTile clears a color without calling it clearing text', (tester) async {
    final setting = ColorNullableSetting(storage: storage, key: 'k', defaultValue: const Color(0xFF112233));
    await pumpTile(tester, ColorNullableSettingTile(setting: setting, label: 'Tint', presets: const [Colors.red]));

    await tester.tap(find.text('Tint'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Clear color'), findsOneWidget);
    expect(find.byTooltip('Clear text'), findsNothing);
    expect(find.text('Clear value'), findsNothing);

    await tester.tap(find.byTooltip('Clear color'));
    await tester.pumpAndSettle();
    expect(setting.value, isNull);
  });

  testWidgets('clearing an int, a date or a map is not called clearing text', (tester) async {
    final count = IntNullableSetting(storage: storage, key: 'count', defaultValue: 1);
    await pumpTile(tester, IntNullableSettingTile(setting: count, label: 'Count'));
    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();
    expect(find.text('Clear value'), findsOneWidget);
    expect(find.text('Clear text'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final when = DateTimeNullableSetting(storage: storage, key: 'when', defaultValue: DateTime(2020, 6, 15));
    await pumpTile(tester, DateTimeNullableSettingTile(setting: when, label: 'When'));
    await tester.tap(find.text('When'));
    await tester.pumpAndSettle();
    expect(find.text('Clear value'), findsOneWidget);
    expect(find.text('Clear text'), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    final account = MapNullableSetting(
      storage: storage,
      key: 'account',
      defaultValue: const <String, Object?>{'a': 1},
    );
    await pumpTile(tester, MapNullableSettingTile(setting: account, label: 'Account'));
    expect(find.text('Clear value'), findsNothing);
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.text('Clear value'), findsOneWidget);
    expect(find.text('Clear text'), findsNothing);
  });

  testWidgets('DateTimeSettingTile keeps a confirmed date when the time picker is cancelled', (tester) async {
    final setting = DateTimeSetting(storage: storage, key: 'k', defaultValue: DateTime(2020, 6, 15, 14, 30));
    await pumpTile(tester, DateTimeSettingTile(setting: setting, label: 'When'));

    await tester.tap(find.text('When'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(setting.value, DateTime(2020, 6, 20, 14, 30));
  });

  testWidgets('DateTimeSettingTile opens on a value outside the default ten-year range', (tester) async {
    final setting = DateTimeSetting(storage: storage, key: 'k', defaultValue: DateTime(1990, 5, 17));
    await pumpTile(tester, DateTimeSettingTile(setting: setting, label: 'Date', pickTime: false));

    await tester.tap(find.text('Date'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('StringSettingTile does not submit a text the setting rejects', (tester) async {
    final setting = StringSetting(storage: storage, key: 'k', defaultValue: 'a', validator: forbid('bad'));
    await pumpTile(tester, StringSettingTile(setting: setting, label: 'Name'));

    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'bad');
    await tester.pump();

    final ok = find.widgetWithText(TextButton, 'OK');
    expect(tester.widget<TextButton>(ok).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'good');
    await tester.pump();
    await tester.tap(ok);
    await tester.pumpAndSettle();

    expect(setting.value, 'good');
    expect(handler.reports, isEmpty);
  });

  testWidgets('StringSettingTile words a rejected text without repeating it', (tester) async {
    const secret = 's3cret';
    final setting = StringSetting(
      storage: storage,
      key: 'k',
      defaultValue: 'a',
      validator: SettingValidator(
        (value) => value == secret ? ForbiddenValueValidationError(value, debugDescription: 'dev-only') : null,
      ),
    );
    await pumpTile(tester, StringSettingTile(setting: setting, label: 'Password'));

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), secret);
    await tester.pump();

    final error = tester.widget<TextField>(find.byType(TextField)).decoration?.errorText;
    expect(error, 'This value is not allowed');
    expect(error, isNot(contains(secret)));
    expect(error, isNot(contains('dev-only')));
  });

  testWidgets('StringSettingTile words an unknown validation error without its data', (tester) async {
    const secret = 's3cret';
    final setting = StringSetting(
      storage: storage,
      key: 'k',
      defaultValue: 'a',
      validator: SettingValidator((value) => value == secret ? const _SecretError(secret) : null),
    );
    await pumpTile(tester, StringSettingTile(setting: setting, label: 'Password'));

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), secret);
    await tester.pump();

    final error = tester.widget<TextField>(find.byType(TextField)).decoration?.errorText;
    expect(error, 'Enter a valid value');
    expect(error, isNot(contains(secret)));
  });

  testWidgets('StringNullableSettingTile asks for a value when null is rejected', (tester) async {
    final setting = StringNullableSetting(
      storage: storage,
      key: 'k',
      defaultValue: 'a',
      validator: SettingValidator.notNull(debugDescription: 'dev-only'),
    );
    await pumpTile(tester, StringNullableSettingTile(setting: setting, label: 'Name'));

    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).decoration?.errorText, 'Enter a value');
    expect(find.text('dev-only'), findsNothing);
  });

  testWidgets('StringSettingTile words a pattern error without the rejected text', (tester) async {
    const secret = 's3cret';
    final setting = StringSetting(
      storage: storage,
      key: 'k',
      defaultValue: '1',
      validator: SettingValidator.pattern(RegExp(r'^\d+$'), debugDescription: 'digits'),
    );
    await pumpTile(tester, StringSettingTile(setting: setting, label: 'Code'));

    await tester.tap(find.text('Code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), secret);
    await tester.pump();

    final error = tester.widget<TextField>(find.byType(TextField)).decoration?.errorText;
    expect(error, 'Enter a value in the required format');
    expect(error, isNot(contains(secret)));
    expect(error, isNot(contains('digits')));
  });

  testWidgets('StringNullableSettingTile stores an empty text as null', (tester) async {
    final setting = StringNullableSetting(storage: storage, key: 'k', defaultValue: 'a');
    await pumpTile(tester, StringNullableSettingTile(setting: setting, label: 'Name'));

    await tester.tap(find.text('Name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(TextButton, 'OK'));
    await tester.pumpAndSettle();

    expect(setting.value, isNull);
    expect(storage.hasNull('k'), isTrue);
  });

  testWidgets('BoolNullableCheckboxSettingTile stores the next accepted value', (tester) async {
    final setting = BoolNullableSetting(storage: storage, key: 'k');
    await pumpTile(tester, BoolNullableCheckboxSettingTile(setting: setting, label: 'Flag'));

    await tester.tap(find.text('Flag'));
    await tester.pump();
    expect(setting.value, isTrue);

    await tester.tap(find.text('Flag'));
    await tester.pump();
    expect(setting.value, isFalse);
    expect(handler.reports, isEmpty);
  });

  testWidgets('BoolNullableCheckboxSettingTile skips a rejected state and stores the next accepted one', (
    tester,
  ) async {
    final setting = BoolNullableSetting(storage: storage, key: 'k', validator: forbid<bool?>(true));
    await pumpTile(tester, BoolNullableCheckboxSettingTile(setting: setting, label: 'Flag'));

    await tester.tap(find.text('Flag'));
    await tester.pump();

    expect(setting.value, isFalse);
    expect(handler.reports, isEmpty);

    await tester.tap(find.text('Flag'));
    await tester.pump();
    expect(setting.value, isNull);
  });

  testWidgets('BoolNullableCheckboxSettingTile reports when every other state is rejected', (tester) async {
    final setting = BoolNullableSetting(
      storage: storage,
      key: 'k',
      validator: SettingValidator(
        (value) => value == null ? null : ForbiddenValueValidationError(value, debugDescription: 'no'),
      ),
    );
    await pumpTile(tester, BoolNullableCheckboxSettingTile(setting: setting, label: 'Flag'));

    await tester.tap(find.text('Flag'));
    await tester.pump();

    expect(setting.value, isNull);
    expect(handler.reports.single.error.diagnosticKey, setting.diagnosticKey);
  });

  testWidgets('BoolNullableCheckboxTile reports a validator rejection without storing it', (tester) async {
    final notifier = ValueNotifier<bool?>(null);
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsErrorHandlerProvider(
          handler: handler,
          child: Scaffold(
            body: BoolNullableCheckboxTile(
              notifier: notifier,
              label: 'Flag',
              validator: (value) => ForbiddenValueValidationError(value, debugDescription: 'no'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Flag'));
    await tester.pump();

    expect(notifier.value, isNull);
    expect(handler.reports, hasLength(1));
    expect(handler.reports.single.settingName, 'Flag');
  });

  testWidgets('BoolNullableDropdownSettingTile takes state names from TypedSettingsLocalizations', (
    tester,
  ) async {
    final setting = BoolNullableSetting(storage: storage, key: 'k', defaultValue: true)..value = null;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_BoolLabelsDelegate()],
        home: SettingsErrorHandlerProvider(
          handler: handler,
          child: Scaffold(
            body: BoolNullableDropdownSettingTile(setting: setting, label: 'Flag'),
          ),
        ),
      ),
    );

    expect(find.text('empty'), findsOneWidget);
    await tester.tap(find.text('Flag'));
    await tester.pumpAndSettle();
    expect(find.text('on'), findsWidgets);
    expect(find.text('off'), findsOneWidget);
  });

  testWidgets('BoolNullableDropdownSettingTile names null "Not set" by default', (tester) async {
    final setting = BoolNullableSetting(storage: storage, key: 'k', defaultValue: true)..value = null;
    await pumpTile(tester, BoolNullableDropdownSettingTile(setting: setting, label: 'Flag'));

    expect(find.text('Not set'), findsOneWidget);
  });

  testWidgets('SnackbarSettingsErrorHandler reports in a snack bar', (tester) async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 1, validator: forbid(2));
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsErrorHandlerProvider(
          handler: const SnackbarSettingsErrorHandler(),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => setting.editorView(context, label: 'Count').value = 2,
                child: const Text('assign'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('assign'));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Count: This value is not allowed'), findsOneWidget);
    expect(find.textContaining('forbidden'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(setting.value, 1);
  });

  testWidgets('SnackbarSettingsErrorHandler reports in a dialog when no messenger is above the tile', (tester) async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 1, validator: forbid(2));
    await tester.pumpWidget(
      Localizations(
        locale: const Locale('en'),
        delegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              builder: (context) => SettingsErrorHandlerProvider(
                handler: SnackbarSettingsErrorHandler(formatMessage: (name, error) => 'rejected $name'),
                child: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => setting.editorView(context, label: 'Count').value = 2,
                    child: const Text('assign'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('assign'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('rejected Count'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(setting.value, 1);
  });

  testWidgets('DurationSettingTile takes hour and minute labels from Material', (tester) async {
    final setting = DurationSetting(
      storage: storage,
      key: 'k',
      defaultValue: const Duration(hours: 1, minutes: 5, seconds: 3),
    );
    await pumpTile(tester, DurationSettingTile(setting: setting, label: 'Delay'));
    expect(find.text('1h 05m 03s'), findsOneWidget);

    await tester.tap(find.text('Delay'));
    await tester.pumpAndSettle();

    expect(find.text('Hour'), findsOneWidget);
    expect(find.text('Minute'), findsOneWidget);
    expect(find.text('Seconds'), findsOneWidget);
  });

  testWidgets('DurationSettingTile takes chip units from TypedSettingsLocalizations', (tester) async {
    final setting = DurationSetting(
      storage: storage,
      key: 'k',
      defaultValue: const Duration(hours: 1, minutes: 5, seconds: 3),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_DurationUnitsDelegate()],
        home: SettingsErrorHandlerProvider(
          handler: handler,
          child: Scaffold(
            body: DurationSettingTile(setting: setting, label: 'Delay'),
          ),
        ),
      ),
    );

    expect(find.text('1ч 05м 03с'), findsOneWidget);
    expect(find.text('1h 05m 03s'), findsNothing);
  });

  testWidgets('IntListSettingTile takes its list text from TypedSettingsLocalizations', (tester) async {
    final setting = IntListSetting(storage: storage, key: 'k', defaultValue: const []);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_ListMessagesDelegate()],
        home: SettingsErrorHandlerProvider(
          handler: handler,
          child: Scaffold(
            body: IntListSettingTile(setting: setting, label: 'Ids'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ids'));
    await tester.pumpAndSettle();

    expect(find.text('add-item'), findsOneWidget);
    expect(find.text('empty-list'), findsOneWidget);
    expect(find.text('0 rows'), findsOneWidget);
  });

  testWidgets('a list item uses the framework move and delete tooltips', (tester) async {
    final setting = IntListSetting(storage: storage, key: 'k', defaultValue: const [1]);
    await pumpTile(tester, IntListSettingTile(setting: setting, label: 'Ids'));

    await tester.tap(find.text('Ids'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Move up'), findsOneWidget);
    expect(find.byTooltip('Move down'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets('StringListSettingTile keeps a rejected list in the dialog', (tester) async {
    const secret = 's3cret';
    final setting = StringListSetting(
      storage: storage,
      key: 'k',
      defaultValue: const <String>[],
      validator: SettingValidator(
        (value) => value.contains(secret) ? ForbiddenValueValidationError(value, debugDescription: 'dev-only') : null,
      ),
    );
    await pumpTile(tester, StringListSettingTile(setting: setting, label: 'Names'));

    await tester.tap(find.text('Names'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), secret);
    await tester.pump();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pump();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed, isNull);
    expect(find.text('This value is not allowed'), findsOneWidget);
    expect(find.text(secret), findsOneWidget);
    expect(find.textContaining('dev-only'), findsNothing);
    expect(setting.value, isEmpty);
    expect(handler.reports, isEmpty);
  });

  testWidgets('StringListSettingTile moves a dragged item to where it is dropped', (tester) async {
    final setting = StringListSetting(storage: storage, key: 'k', defaultValue: const ['a', 'b', 'c']);
    await pumpTile(tester, StringListSettingTile(setting: setting, label: 'Names'));
    await tester.tap(find.text('Names'));
    await tester.pumpAndSettle();

    final list = tester.widget<ReorderableListView>(find.byType(ReorderableListView));
    list.onReorderItem!(0, 1);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(setting.value, ['b', 'a', 'c']);
  });

  testWidgets('a long list item ellipsizes in the list dialog', (tester) async {
    final setting = StringListSetting(storage: storage, key: 'k', defaultValue: ['https://example.com/' * 10]);
    await pumpTile(tester, StringListSettingTile(setting: setting, label: 'Names'));
    await tester.tap(find.text('Names'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('IntListSettingTile keeps a rejected list in the dialog', (tester) async {
    final setting = IntListSetting(
      storage: storage,
      key: 'k',
      defaultValue: const <int>[],
      validator: SettingValidator((value) => value.isNotEmpty ? ForbiddenValueValidationError(value) : null),
    );
    await pumpTile(tester, IntListSettingTile(setting: setting, label: 'Ids'));

    await tester.tap(find.text('Ids'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.pump();
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pump();

    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed, isNull);
    expect(find.text('This value is not allowed'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(setting.value, isEmpty);
    expect(handler.reports, isEmpty);
  });

  testWidgets('MapSettingTile keeps a rejected object in the dialog', (tester) async {
    final setting = MapSetting(
      storage: storage,
      key: 'k',
      defaultValue: const <String, Object?>{},
      validator: SettingValidator(
        (value) =>
            value.containsKey('token') ? ForbiddenValueValidationError(value, debugDescription: 'dev-only') : null,
      ),
    );
    await pumpTile(tester, MapSettingTile(setting: setting, label: 'Account'));

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{"token": "s3cret"}');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).decoration?.errorText, 'This value is not allowed');
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed, isNull);
    expect(find.textContaining('dev-only'), findsNothing);
    expect(setting.value, isEmpty);
    expect(handler.reports, isEmpty);
  });

  testWidgets('MapNullableSettingTile keeps an empty object when null is rejected', (tester) async {
    final setting = MapNullableSetting(
      storage: storage,
      key: 'k',
      defaultValue: const <String, Object?>{'a': 1},
      validator: SettingValidator.notNull(debugDescription: 'dev-only'),
    );
    await pumpTile(tester, MapNullableSettingTile(setting: setting, label: 'Account'));

    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{}');
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).decoration?.errorText, 'Enter a value');
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed, isNull);
    expect(find.textContaining('dev-only'), findsNothing);
    expect(setting.value, {'a': 1});
    expect(handler.reports, isEmpty);
  });

  testWidgets('a captured editor view reports through the handler now above it', (tester) async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 1, validator: forbid(2));
    final first = _RecordingErrorHandler();
    final second = _RecordingErrorHandler();
    var current = first as SettingsErrorHandler;
    late ValueNotifier<int> view;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => SettingsErrorHandlerProvider(
            handler: current,
            child: Builder(
              builder: (context) {
                view = setting.editorView(context, label: 'Count');
                return TextButton(
                  onPressed: () => setState(() => current = second),
                  child: const Text('swap'),
                );
              },
            ),
          ),
        ),
      ),
    );
    final captured = view;

    await tester.tap(find.text('swap'));
    await tester.pump();
    captured.value = 2;

    expect(first.reports, isEmpty);
    expect(second.reports, hasLength(1));
  });

  testWidgets('a rejected value on an unmounted editor is reported without throwing', (tester) async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 1, validator: forbid(2));
    late ValueNotifier<int> view;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            view = setting.editorView(context, label: 'Count');
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());

    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    try {
      view.value = 2;
    } finally {
      FlutterError.onError = previous;
    }

    expect(reported, hasLength(1));
    expect(reported.single.exception, isA<SettingValidationException>());
    expect(setting.value, 1);
  });

  testWidgets('DialogSettingsErrorHandler reports in a dialog that its OK closes', (tester) async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 1, validator: forbid(2));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => setting.editorView(context, label: 'Count').value = 2,
              child: const Text('assign'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('assign'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Count: This value is not allowed'), findsOneWidget);
    expect(find.textContaining('forbidden'), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('assign'), findsOneWidget);
  });

  testWidgets('the default handler leaves a rejected text out of the message', (tester) async {
    const secret = 's3cret';
    final setting = StringSetting(
      storage: storage,
      key: 'k',
      defaultValue: 'a',
      validator: SettingValidator(
        (value) => value == secret ? const _SecretError(secret) : null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_HandlerMessagesDelegate()],
        home: SettingsErrorHandlerProvider(
          handler: const SnackbarSettingsErrorHandler(),
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => setting.editorView(context, label: 'Password').value = secret,
                child: const Text('assign'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('assign'));
    await tester.pump();

    expect(find.text('Password: nope'), findsOneWidget);
    expect(find.textContaining(secret), findsNothing);
  });

  testWidgets('DoubleSettingTile keeps a value outside the slider until the slider moves', (tester) async {
    final setting = DoubleSetting(storage: storage, key: 'k', defaultValue: 10);
    await pumpTile(tester, DoubleSettingTile(setting: setting, label: 'Level', min: 0, max: 5));

    await tester.tap(find.text('Level'));
    await tester.pumpAndSettle();
    expect(find.text('10.00'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    expect(setting.value, 10);

    await tester.tap(find.text('Level'));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(3);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    expect(setting.value, 3);
  });

  testWidgets('IntSettingTile does not submit a value outside min and max', (tester) async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 10);
    await pumpTile(tester, IntSettingTile(setting: setting, label: 'Count', min: 0, max: 5));

    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();
    expect(find.text('Maximum value is 5'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed, isNull);
    expect(setting.value, 10);

    await tester.enterText(find.byType(TextField), '-');
    await tester.pump();
    expect(find.text('Enter a valid integer'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed, isNull);

    await tester.enterText(find.byType(TextField), '4');
    await tester.pump();
    expect(find.text('Maximum value is 5'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'OK'));
    await tester.pumpAndSettle();
    expect(setting.value, 4);
  });

  testWidgets('IntSettingTile rejects an initial value below min', (tester) async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: -3);
    await pumpTile(tester, IntSettingTile(setting: setting, label: 'Count', min: 0));

    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();
    expect(find.text('Minimum value is 0'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'OK')).onPressed, isNull);
    expect(setting.value, -3);
  });

  testWidgets('the integer editor uses TypedSettingsLocalizations from the tree', (tester) async {
    final setting = IntSetting(storage: storage, key: 'k', defaultValue: 10);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_FixedMessagesDelegate()],
        home: SettingsErrorHandlerProvider(
          handler: handler,
          child: Scaffold(
            body: IntSettingTile(setting: setting, label: 'Count', max: 5),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();
    expect(find.text('max 5'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '-');
    await tester.pump();
    expect(find.text('not-an-int'), findsOneWidget);
    expect(setting.value, 10);
  });

  test('a date bound moves to the current value when that value lies beyond it', () {
    final early = DateTime(2019, 6);
    final widened = datePickerBounds(early, firstDate: DateTime(2020), lastDate: DateTime(2020, 12, 31));
    expect(widened.initial, early);
    expect(widened.first, early);
    expect(widened.last, DateTime(2020, 12, 31));

    final late = DateTime(2021, 3);
    final extended = datePickerBounds(late, firstDate: DateTime(2020), lastDate: DateTime(2020, 12, 31));
    expect(extended.initial, late);
    expect(extended.first, DateTime(2020));
    expect(extended.last, late);

    final inside = DateTime(2020, 6);
    final kept = datePickerBounds(inside, firstDate: DateTime(2020), lastDate: DateTime(2020, 12, 31));
    expect(kept.initial, inside);
    expect(kept.first, DateTime(2020));
    expect(kept.last, DateTime(2020, 12, 31));
  });

  testWidgets('BoolCheckboxTile edits a ValueNotifier without a Setting', (tester) async {
    final notifier = ValueNotifier(false);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BoolCheckboxTile(notifier: notifier, label: 'Draft'),
        ),
      ),
    );

    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isFalse);

    await tester.tap(find.text('Draft'));
    await tester.pump();

    expect(notifier.value, isTrue);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value, isTrue);
  });
}

final class _SecretError extends ValidationError {
  const _SecretError(this.secret);

  final String secret;

  @override
  List<Object?> get props => [secret];
}

class _BoolLabels extends TypedSettingsLocalizations {
  const _BoolLabels();

  @override
  String get enabledLabel => 'on';

  @override
  String get disabledLabel => 'off';

  @override
  String get notSetLabel => 'empty';
}

class _DurationUnits extends TypedSettingsLocalizations {
  const _DurationUnits();

  @override
  String get durationHourUnit => 'ч';

  @override
  String get durationMinuteUnit => 'м';

  @override
  String get durationSecondUnit => 'с';
}

class _DurationUnitsDelegate extends LocalizationsDelegate<TypedSettingsLocalizations> {
  const _DurationUnitsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<TypedSettingsLocalizations> load(Locale locale) => SynchronousFuture(const _DurationUnits());

  @override
  bool shouldReload(covariant _DurationUnitsDelegate old) => false;
}

class _HandlerMessages extends TypedSettingsLocalizations {
  const _HandlerMessages();

  @override
  String get invalidValue => 'nope';
}

class _HandlerMessagesDelegate extends LocalizationsDelegate<TypedSettingsLocalizations> {
  const _HandlerMessagesDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<TypedSettingsLocalizations> load(Locale locale) => SynchronousFuture(const _HandlerMessages());

  @override
  bool shouldReload(covariant _HandlerMessagesDelegate old) => false;
}

class _BoolLabelsDelegate extends LocalizationsDelegate<TypedSettingsLocalizations> {
  const _BoolLabelsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<TypedSettingsLocalizations> load(Locale locale) => SynchronousFuture(const _BoolLabels());

  @override
  bool shouldReload(covariant _BoolLabelsDelegate old) => false;
}

class _ListMessages extends TypedSettingsLocalizations {
  const _ListMessages();

  @override
  String get newListValue => 'add-item';

  @override
  String get noListItems => 'empty-list';

  @override
  String listItemCount(int count) => '$count rows';
}

class _ListMessagesDelegate extends LocalizationsDelegate<TypedSettingsLocalizations> {
  const _ListMessagesDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<TypedSettingsLocalizations> load(Locale locale) => SynchronousFuture(const _ListMessages());

  @override
  bool shouldReload(covariant _ListMessagesDelegate old) => false;
}

class _FixedMessages extends TypedSettingsLocalizations {
  const _FixedMessages();

  @override
  String get invalidInteger => 'not-an-int';

  @override
  String rangeValue({num? min, num? max}) => min != null ? 'min $min' : 'max $max';
}

class _FixedMessagesDelegate extends LocalizationsDelegate<TypedSettingsLocalizations> {
  const _FixedMessagesDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<TypedSettingsLocalizations> load(Locale locale) => SynchronousFuture(const _FixedMessages());

  @override
  bool shouldReload(covariant _FixedMessagesDelegate old) => false;
}

class _RecordingErrorHandler extends SettingsErrorHandler {
  final List<({String settingName, SettingValidationException error})> reports = [];

  @override
  void handleValidationError(BuildContext context, String settingName, SettingValidationException error) {
    reports.add((settingName: settingName, error: error));
  }
}
