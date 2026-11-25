import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/typed_settings_flutter_extend.dart';
import 'package:typed_settings_json_schema_flutter/src/map_editor_dialog.dart';

void main() {
  /// Pumps an app, opens the dialog and returns the future of its result.
  Future<Future<DialogResult<Map<String, Object?>?>?>> pumpDialog(
    WidgetTester tester, {
    required Map<String, Object?> initial,
    ObjectSchema? schema,
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
                  schema: schema,
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

  final schema = Schema.fromMap({
    'type': 'object',
    'properties': {
      'name': {'type': 'string'},
      'age': {'type': 'integer', 'minimum': 0},
    },
    'required': ['name'],
  }) as ObjectSchema;

  testWidgets('renders form fields from schema and returns edited value on OK', (tester) async {
    final result = await pumpDialog(tester, initial: {'name': 'Bob', 'age': 3}, schema: schema);

    expect(find.widgetWithText(TextField, 'Bob'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Bob'), 'Alice');
    await tester.pumpAndSettle();

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect((await result)?.value, {'name': 'Alice', 'age': 3});
  });

  testWidgets('OK is disabled while the value violates the schema', (tester) async {
    final result = await pumpDialog(tester, initial: {'age': 1}, schema: schema);

    expect(okButton(tester).onPressed, isNull);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('raw JSON tab edits the same value and gates OK on parse errors', (tester) async {
    final result = await pumpDialog(tester, initial: {'name': 'Bob'}, schema: schema);

    await tester.tap(find.text('Raw JSON'));
    await tester.pumpAndSettle();

    final rawField = find.byType(TextFormField);
    expect(rawField, findsOneWidget);

    await tester.enterText(rawField, '{"name": ');
    await tester.pumpAndSettle();
    expect(okButton(tester).onPressed, isNull);

    await tester.enterText(rawField, '{"name": "Raw", "age": 7}');
    await tester.pumpAndSettle();
    expect(okButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect((await result)?.value, {'name': 'Raw', 'age': 7});
  });

  testWidgets('non-object JSON in the raw tab disables OK', (tester) async {
    await pumpDialog(tester, initial: {'name': 'Bob'});

    await tester.tap(find.text('Raw JSON'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '[1, 2, 3]');
    await tester.pumpAndSettle();

    expect(okButton(tester).onPressed, isNull);
    expect(find.text('JSON value must be an object'), findsOneWidget);
  });

  testWidgets('a failed rebuild stops the spinner and shows the failure', (tester) async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => MapEditorDialog(
                label: 'Test map',
                initial: const {},
                registry: _BoomRegistry(),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Unable to build an editor'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(okButton(tester).onPressed, isNull);
    expect(reported.single.exception, isA<StateError>());
  });
}

class _BoomRegistry extends JsonHandlerRegistry {
  _BoomRegistry() : super(schemaMerger: SchemaMerger.withDefaults());

  @override
  Future<T> withValidationContext<T>({
    required Schema? itemSchema,
    required Schema? rootSchema,
    required Future<T> Function(ValidationContext? validationContext) body,
  }) async {
    throw StateError('boom');
  }

  @override
  JsonFieldHandler<JsonFieldState> get unknownFieldHandler => throw UnimplementedError();

  @override
  List<JsonFieldHandler<JsonFieldState>> pickableHandlers({
    required FieldResolveContext resolveContext,
    Schema? schema,
  }) => throw UnimplementedError();

  @override
  JsonFieldStateBuilder<JsonFieldState> stateBuilderFor({
    required Schema schema,
    required PresenceValue<dynamic>? value,
    required FieldResolveContext resolveContext,
  }) => throw UnimplementedError();

  @override
  JsonFieldStateBuilder<JsonFieldState>? stateBuilderForValue({
    required PresenceValue<dynamic> value,
    required FieldResolveContext resolveContext,
  }) => throw UnimplementedError();

  @override
  List<JsonFieldHandler<JsonFieldState>> handlersForSchema({
    required Schema schema,
    required FieldResolveContext resolveContext,
  }) => throw UnimplementedError();

  @override
  JsonFieldHandler<JsonFieldState> handlerForField(JsonFieldState field) => throw UnimplementedError();
}
