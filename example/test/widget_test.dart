import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_example/app_settings.dart';
import 'package:typed_settings_example/home_page.dart';

void main() {
  test('every setting has a valid default', () {
    final settings = AppSettings(storage: InMemoryStorage());
    addTearDown(settings.close);

    expect(settings.todoList.value['name'], 'Inbox');
    expect(settings.fallbackLanguage.value, const Locale('en'));
    expect(settings.quietHoursStart.value, const TimeOfDay(hour: 22, minute: 0));
    expect(settings.accentColor.validate(Colors.red), isNotNull);
    expect(settings.accentColor.validate(const Color(0xFFF44336)), isNotNull);
  });

  testWidgets('the settings page lays out every tile and follows the theme setting', (tester) async {
    final settings = AppSettings(storage: InMemoryStorage());
    addTearDown(settings.close);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(tabs: [(title: 'In Memory', settings: settings)]),
      ),
    );

    await tester.dragUntilVisible(find.text('Launch count'), find.byType(ListView), const Offset(0, -300));
    expect(tester.takeException(), isNull);

    settings.themeMode.value = ThemeMode.dark;
    await tester.pump();
    expect(Theme.of(tester.element(find.text('Launch count'))).brightness, Brightness.dark);
  });
}
