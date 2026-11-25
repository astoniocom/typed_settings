import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';

void main() {
  late InMemoryStorage storage;

  setUp(() => storage = InMemoryStorage());

  IntSetting intSetting({SettingValidator<int>? validator}) =>
      IntSetting(storage: storage, key: 'k', defaultValue: 7, validator: validator);

  test('a setting is the ValueListenable its listeners observe', () {
    final setting = intSetting();
    final ValueListenable<int> view = setting;
    final seen = <int>[];
    void listener() => seen.add(view.value);
    view.addListener(listener);

    setting.value = 3;
    view.removeListener(listener);
    setting.value = 4;

    expect(seen, [3]);
    expect(view.value, 4);
  });

  testWidgets('a setting drives a ValueListenableBuilder', (tester) async {
    final setting = intSetting();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder(
          valueListenable: setting,
          builder: (context, value, _) => Text('$value'),
        ),
      ),
    );
    expect(find.text('7'), findsOneWidget);

    setting.value = 3;
    await tester.pump();

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('editorView is equal for the same setting, context and label', (tester) async {
    final setting = intSetting();
    late BuildContext context;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (built) {
            context = built;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(setting.editorView(context, label: 'Volume'), setting.editorView(context, label: 'Volume'));
    expect(setting.editorView(context, label: 'Volume'), isNot(setting.editorView(context, label: 'Other')));

    final view = setting.editorView(context, label: 'Volume');
    final seen = <int>[];
    view.addListener(() => seen.add(view.value));
    view.dispose();
    setting.value = 3;
    expect(seen, isEmpty);
    expect(setting.value, 3);
  });
}
