import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/src/widgets/map_editor_dialog.dart';
import 'package:typed_settings_flutter/typed_settings_flutter_extend.dart';

void main() {
  /// Pumps an app, opens the dialog and returns the future of its result.
  Future<Future<DialogResult<Map<String, Object?>?>?>> pumpDialog(
    WidgetTester tester, {
    required Map<String, Object?> initial,
    bool allowClear = false,
  }) async {
    late final Future<DialogResult<Map<String, Object?>?>?> result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              result = showDialog<DialogResult<Map<String, Object?>?>>(
                context: context,
                builder: (context) => MapEditorDialog(
                  label: 'Test map',
                  initial: initial,
                  allowClear: allowClear,
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  FilledButton okButton(WidgetTester tester) => tester.widget<FilledButton>(
    find.ancestor(of: find.text('OK'), matching: find.byType(FilledButton)),
  );

  testWidgets('returns the edited JSON object on OK', (tester) async {
    final result = await pumpDialog(tester, initial: {'name': 'Bob', 'age': 3});

    await tester.enterText(find.byType(TextField), '{"name": "Alice", "age": 3}');
    await tester.pump();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect((await result)?.value, {'name': 'Alice', 'age': 3});
  });

  testWidgets('OK is disabled while the text is not JSON, and the parse error is shown', (tester) async {
    final result = await pumpDialog(tester, initial: {'name': 'Bob'});

    await tester.enterText(find.byType(TextField), '{"name": ');
    await tester.pump();

    expect(okButton(tester).onPressed, isNull);
    expect(find.text('Invalid JSON at position 9'), findsOneWidget);
    expect(find.textContaining('Unexpected'), findsNothing);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('a JSON value that is not an object disables OK', (tester) async {
    await pumpDialog(tester, initial: {'name': 'Bob'});

    await tester.enterText(find.byType(TextField), '[1, 2, 3]');
    await tester.pump();

    expect(okButton(tester).onPressed, isNull);
    expect(find.text('JSON value must be an object'), findsOneWidget);
  });

  testWidgets('a non-object value and invalid JSON use TypedSettingsLocalizations', (tester) async {
    late final Future<DialogResult<Map<String, Object?>?>?> result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_MapMessagesDelegate()],
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              result = showDialog<DialogResult<Map<String, Object?>?>>(
                context: context,
                builder: (context) => const MapEditorDialog(label: 'Test map', initial: {}),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '[1]');
    await tester.pump();

    expect(find.text('not-an-object'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '{"name": ');
    await tester.pump();
    expect(find.text('bad-json:9'), findsOneWidget);
    expect(find.textContaining('Unexpected'), findsNothing);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });
}

class _MapMessages extends TypedSettingsLocalizations {
  const _MapMessages();

  @override
  String get jsonMustBeObject => 'not-an-object';

  @override
  String invalidJson(int? offset) => 'bad-json:$offset';
}

class _MapMessagesDelegate extends LocalizationsDelegate<TypedSettingsLocalizations> {
  const _MapMessagesDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<TypedSettingsLocalizations> load(Locale locale) => SynchronousFuture(const _MapMessages());

  @override
  bool shouldReload(covariant _MapMessagesDelegate old) => false;
}
