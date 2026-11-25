import 'dart:async';

import 'package:test/test.dart';
import 'package:typed_settings/src/settings/internal/setting_notifier.dart';

void main() {
  late int value;
  late int reads;
  late Exception? readError;
  late List<Object> listenerErrors;
  late SettingNotifier<int> notifier;

  setUp(() {
    value = 0;
    reads = 0;
    readError = null;
    listenerErrors = [];
    notifier = SettingNotifier(
      read: () {
        reads++;
        if (readError case final error?) throw error;
        return value;
      },
      onListenerError: (error, _) => listenerErrors.add(error),
    );
  });

  group('listeners', () {
    test('are notified in registration order', () {
      final calls = <String>[];
      notifier
        ..add(() => calls.add('a'))
        ..add(() => calls.add('b'))
        ..notify();

      expect(calls, ['a', 'b']);
    });

    test('a listener that throws is handed over and the rest are still notified', () {
      var laterCalled = false;
      notifier
        ..add(() => throw StateError('listener bug'))
        ..add(() => laterCalled = true)
        ..notify();

      expect(listenerErrors.single, isA<StateError>());
      expect(laterCalled, isTrue);
    });

    test('a removed listener is not notified', () {
      var calls = 0;
      void listener() => calls++;
      notifier
        ..add(listener)
        ..remove(listener)
        ..notify();

      expect(calls, 0);
    });

    test('a listener that closes the notifier ends the notification', () {
      var laterCalls = 0;
      notifier
        ..add(notifier.close)
        ..add(() => laterCalls++)
        ..notify();

      expect(laterCalls, 0);
      expect(listenerErrors, isEmpty);
    });
  });

  group('asStream', () {
    test('is one stream that starts each subscription with the current value, then follows notify', () async {
      expect(notifier.asStream(), same(notifier.asStream()));

      value = 1;
      final received = <int>[];
      final subscription = notifier.asStream().listen(received.add);
      await pumpEventQueue();
      value = 2;
      notifier.notify();
      await pumpEventQueue();

      expect(received, [1, 2]);
      await subscription.cancel();
    });

    test('reads once per notify for all subscribers', () async {
      final first = notifier.asStream().listen((_) {});
      final second = notifier.asStream().listen((_) {});
      await pumpEventQueue();
      reads = 0;

      notifier.notify();
      await pumpEventQueue();

      expect(reads, 1);
      await first.cancel();
      await second.cancel();
    });

    test('a read that throws is an error on the subscription, not a listener error', () async {
      readError = const FormatException('unusable');
      final errors = <Object>[];
      final subscription = notifier.asStream().listen((_) {}, onError: errors.add);
      await pumpEventQueue();
      notifier.notify();
      await pumpEventQueue();

      expect(errors, [isA<FormatException>(), isA<FormatException>()]);
      expect(listenerErrors, isEmpty);
      await subscription.cancel();
    });

    test('once the last subscriber leaves, notify no longer reads; a later listen works', () async {
      final subscription = notifier.asStream().listen((_) {});
      await pumpEventQueue();
      await subscription.cancel();
      reads = 0;

      notifier.notify();
      expect(reads, 0);

      value = 5;
      expect(await notifier.asStream().first, 5);
    });
  });

  group('close', () {
    test('ends every subscription, drops the listeners, and a later listen ends at once', () async {
      var calls = 0;
      notifier.add(() => calls++);
      final done = Completer<void>();
      notifier.asStream().listen((_) {}, onDone: done.complete);
      await pumpEventQueue();

      notifier.close();
      await done.future;
      notifier.notify();

      expect(calls, 0);
      expect(await notifier.asStream().toList(), isEmpty);
    });

    test('closing again does nothing', () {
      notifier.close();
      expect(notifier.close, returnsNormally);
    });
  });
}
