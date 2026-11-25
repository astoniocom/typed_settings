import 'package:listen/listen.dart';
import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

void main() {
  late InMemoryStorage storage;

  setUp(() => storage = InMemoryStorage());

  IntSetting intSetting({SettingValidator<int>? validator}) =>
      IntSetting(storage: storage, key: 'k', defaultValue: 7, validator: validator);

  test('the view shares the value and the listeners, and dispose leaves the setting usable', () {
    final setting = intSetting();
    final ValueNotifier<int> view = setting.asValueNotifier();
    final fromView = <int>[];
    final fromSetting = <int>[];
    view.addListener(() => fromView.add(view.value));
    setting.addListener(() => fromSetting.add(setting.value));

    view.value = 3;
    view.dispose();
    setting.value = 4;

    expect(fromView, [3]);
    expect(fromSetting, [3, 4]);
    expect(setting.value, 4);
    expect(() => view.value = 5, throwsStateError);
  });

  test('a rejected value goes to the handler and is not written', () {
    const negative = ForbiddenValueValidationError(-1);
    final setting = intSetting(validator: SettingValidator((value) => value < 0 ? negative : null));
    final errors = <SettingValidationException>[];
    final view = setting.asValueNotifier(onValidationError: errors.add);

    view.value = -1;

    expect(errors.single.error, negative);
    expect(storage.getInt('k'), isNull);
    expect(view.value, 7);
  });

  test('without a handler the rejection propagates', () {
    final view = intSetting(
      validator: SettingValidator((value) => value < 0 ? const ForbiddenValueValidationError(-1) : null),
    ).asValueNotifier();

    expect(() => view.value = -1, throwsA(isA<SettingValidationException>()));
  });

  test('two views with the same handler are equal', () {
    final setting = intSetting();
    void handler(SettingValidationException _) {}

    expect(setting.asValueNotifier(onValidationError: handler), setting.asValueNotifier(onValidationError: handler));
    expect(setting.asValueNotifier(onValidationError: handler), isNot(setting.asValueNotifier()));
  });

  test('two views with the same method as the handler are equal', () {
    final setting = intSetting();
    final errors = <SettingValidationException>[];

    final first = setting.asValueNotifier(onValidationError: errors.add);
    final second = setting.asValueNotifier(onValidationError: errors.add);

    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect(first, isNot(setting.asValueNotifier(onValidationError: <SettingValidationException>[].add)));
  });

  test('an equal view removes the listener the first view added', () {
    final setting = intSetting();
    final seen = <int>[];
    void listener() => seen.add(setting.value);

    setting.asValueNotifier().addListener(listener);
    setting.asValueNotifier().removeListener(listener);
    setting.value = 3;

    expect(seen, isEmpty);
  });

  test('a disposed setting gives no view', () {
    final setting = intSetting()..dispose();

    expect(setting.asValueNotifier, throwsStateError);
  });

  test('a throwing listener is reported and the next one is still called', () {
    final reported = <Object>[];
    final previous = Listenable.onError;
    Listenable.onError = (error, stackTrace, context) {
      reported.add(error);
    };
    addTearDown(() => Listenable.onError = previous);

    final view = intSetting().asValueNotifier()
      ..addListener(() => throw StateError('boom'))
      ..addListener(() => reported.add('next'));

    view.notifyListeners();

    expect(reported, [isA<StateError>(), 'next']);
  });
}
