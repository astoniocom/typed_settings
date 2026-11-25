import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_backend.dart';
import 'package:typed_settings_conformance/typed_settings_conformance.dart';

void main() {
  late RecordingObserver observer;
  late KeyChangeNotifier notifier;
  late List<String> calls;

  setUp(() {
    observer = RecordingObserver();
    notifier = KeyChangeNotifier(report: observer.report);
    calls = [];
  });

  test('notifies the listeners of the changed key only, in the order they were added', () {
    notifier
      ..add('k', () => calls.add('first'))
      ..add('k', () => calls.add('second'))
      ..add('other', () => calls.add('other'));

    notifier.notify('k');

    expect(calls, ['first', 'second']);
  });

  test('a listener added twice is called twice, and one removal takes one of them out', () {
    void listener() => calls.add('listener');
    notifier
      ..add('k', listener)
      ..add('k', listener);

    notifier.notify('k');
    expect(calls, hasLength(2));

    notifier.remove('k', listener);
    calls.clear();
    notifier.notify('k');
    expect(calls, hasLength(1));
    expect(notifier.listenedKeys, ['k']);
  });

  test('removing a listener that is not registered changes nothing', () {
    notifier
      ..add('k', () => calls.add('k'))
      ..remove('k', () {})
      ..remove('none', () {});

    notifier.notify('k');

    expect(calls, ['k']);
    expect(notifier.listenedKeys, ['k']);
  });

  test('a listener removed by another during a notification is not called by it', () {
    void removed() => calls.add('removed');
    notifier
      ..add('k', () => notifier.remove('k', removed))
      ..add('k', removed);

    notifier.notify('k');

    expect(calls, isEmpty);
    expect(observer.events, isEmpty);
  });

  test('a listener that removes itself while notified leaves the others notified', () {
    late void Function() once;
    once = () {
      calls.add('once');
      notifier.remove('k', once);
    };
    notifier
      ..add('k', once)
      ..add('k', () => calls.add('after'));

    notifier
      ..notify('k')
      ..notify('k');

    expect(calls, ['once', 'after', 'after']);
  });

  test('a listener added during a notification is first called on the next one', () {
    notifier.add('k', () {
      calls.add('adder');
      if (calls.length == 1) notifier.add('k', () => calls.add('added'));
    });

    notifier.notify('k');
    expect(calls, ['adder']);

    notifier.notify('k');
    expect(calls, ['adder', 'adder', 'added']);
  });

  test('a throwing listener is reported under its key, and the next listeners still run', () {
    final error = StateError('listener bug');
    notifier
      ..add('k', () => throw error)
      ..add('k', () => calls.add('after'));

    notifier.notify('k');

    expect(calls, ['after']);
    expect(
      observer.events.single,
      isA<ListenerErrorEvent>()
          .having((e) => e.source, 'source', ListenerSource.storageKey)
          .having((e) => e.key, 'key', 'k')
          .having((e) => e.error, 'error', same(error)),
    );
  });

  test('notifying every key reaches each listened key once, and no key without listeners', () {
    void listener() {}
    notifier
      ..add('a', () => calls.add('a'))
      ..add('b', () => calls.add('b'))
      ..add('gone', listener)
      ..remove('gone', listener);

    notifier.notifyAll();

    expect(calls, unorderedEquals(['a', 'b']));
  });

  test('tells which keys have listeners, as a snapshot', () {
    void listener() {}
    notifier.add('k', listener);
    final keys = notifier.listenedKeys;

    notifier.remove('k', listener);

    expect(keys, ['k']);
    expect(notifier.listenedKeys, isEmpty);
  });
}
