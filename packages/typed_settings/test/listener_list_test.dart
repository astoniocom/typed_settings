import 'package:test/test.dart';
import 'package:typed_settings/src/foundation/listener_list.dart';

void main() {
  late ListenerList listeners;
  late List<String> calls;
  late List<Object> errors;

  setUp(() {
    listeners = ListenerList();
    calls = [];
    errors = [];
  });

  void notify() => listeners.notify((error, _) => errors.add(error));

  test('calls the listeners in the order they were added, once per registration', () {
    void a() => calls.add('a');
    listeners
      ..add(a)
      ..add(() => calls.add('b'))
      ..add(a);

    notify();

    expect(calls, ['a', 'b', 'a']);
  });

  test('remove takes out the earliest registration only, and ignores an unknown listener', () {
    void a() => calls.add('a');
    listeners
      ..add(a)
      ..add(() => calls.add('b'))
      ..add(a)
      ..remove(a)
      ..remove(() {});

    notify();

    expect(calls, ['b', 'a']);
  });

  test('a listener removed during a notification is not called by it', () {
    void removed() => calls.add('removed');
    listeners
      ..add(() => listeners.remove(removed))
      ..add(removed);

    notify();

    expect(calls, isEmpty);
  });

  test('removing one registration of a listener added twice during a notification skips one call', () {
    void twice() => calls.add('twice');
    listeners
      ..add(() => listeners.remove(twice))
      ..add(twice)
      ..add(twice);

    notify();

    expect(calls, ['twice']);
  });

  test('clear during a notification stops it', () {
    listeners
      ..add(() => calls.add('first'))
      ..add(listeners.clear)
      ..add(() => calls.add('after'));

    notify();

    expect(calls, ['first']);
    expect(listeners.isEmpty, isTrue);
  });

  test('a listener added during a notification is first called by the next one', () {
    var added = false;
    listeners.add(() {
      calls.add('adder');
      if (added) return;
      added = true;
      listeners.add(() => calls.add('added'));
    });

    notify();
    expect(calls, ['adder']);

    notify();
    expect(calls, ['adder', 'adder', 'added']);
  });

  test('a throwing listener goes to onError and the next ones are still called', () {
    final error = StateError('listener bug');
    listeners
      ..add(() => throw error)
      ..add(() => calls.add('after'));

    notify();

    expect(errors, [same(error)]);
    expect(calls, ['after']);
  });

  test('is empty until a listener is added and after the last is removed', () {
    void a() {}
    expect(listeners.isEmpty, isTrue);
    listeners.add(a);
    expect(listeners.isEmpty, isFalse);
    listeners.remove(a);
    expect(listeners.isEmpty, isTrue);
  });
}
