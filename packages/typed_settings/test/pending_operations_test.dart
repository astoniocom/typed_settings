import 'dart:async';

import 'package:test/test.dart';
import 'package:typed_settings/src/storage_kit/pending_operations.dart';

void main() {
  group('PendingOperations', () {
    void ignoreSettled(int sequence, OperationFailure? failure) {}

    test('wait covers the operations enqueued before the call, not ones enqueued while waiting', () async {
      final pending = PendingOperations();
      final firstGate = Completer<void>();
      final secondGate = Completer<void>();

      pending.enqueue('a', () => firstGate.future, ignoreSettled);

      var waited = false;
      final waiting = pending.wait().then((_) => waited = true);
      // While `a` is in flight, enqueue `b` that is held open indefinitely.
      pending.enqueue('b', () => secondGate.future, ignoreSettled);

      firstGate.complete();
      await waiting;

      expect(waited, isTrue, reason: 'a later write of another key must not starve wait');
      expect(pending.isNotEmpty, isTrue, reason: '`b` is still running');
      secondGate.complete();
      await pending.wait();
      expect(pending.isNotEmpty, isFalse);
    });

    test('wait is not starved by a key that is written continuously', () async {
      final pending = PendingOperations();
      final gate = Completer<void>();
      var writes = 0;
      var stop = false;
      // Every write of `b` enqueues the next one while it is still running,
      // so `b` is never idle until told to stop.
      void writeB() {
        pending.enqueue('b', () async {
          writes++;
          await Future<void>.delayed(Duration.zero);
          if (!stop) writeB();
        }, ignoreSettled);
      }

      pending.enqueue('a', () => gate.future, ignoreSettled);
      writeB();
      final waiting = pending.wait();
      gate.complete();
      await waiting;

      expect(writes, greaterThanOrEqualTo(1));
      expect(pending.isNotEmpty, isTrue, reason: '`b` is still being written');
      stop = true;
      await pending.wait();
      expect(pending.isNotEmpty, isFalse);
    });

    test('wait covers a deferred operation it saw even after a later one supersedes it', () async {
      final pending = PendingOperations();
      final firstGate = Completer<void>();
      final thirdGate = Completer<void>();
      final ran = <String>[];

      pending.enqueue('k', () => firstGate.future, ignoreSettled);
      pending.enqueue('k', () async => ran.add('second'), ignoreSettled); // deferred behind first

      var waited = false;
      final waiting = pending.wait().then((_) => waited = true);
      // Enqueued after wait(): supersedes `second` and now carries its effect.
      pending.enqueue('k', () async {
        ran.add('third');
        await thirdGate.future;
      }, ignoreSettled);

      firstGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(ran, ['third']);
      expect(waited, isFalse, reason: 'the write that replaced `second` must be waited for');

      thirdGate.complete();
      await waiting;
      expect(waited, isTrue);
    });

    test('errors go to the callback and do not fail wait', () async {
      final pending = PendingOperations();
      final failures = <OperationFailure?>[];

      pending.enqueue('bad', () async => throw StateError('boom'), (sequence, failure) => failures.add(failure));
      await pending.wait();

      expect(failures.single?.error, isA<StateError>().having((e) => e.message, 'message', 'boom'));
      expect(failures.single?.stackTrace, isNotNull);
    });

    test('every operation settles once, with its number and its outcome', () async {
      final pending = PendingOperations();
      final settled = <(int, bool)>[];
      void record(int sequence, OperationFailure? failure) => settled.add((sequence, failure != null));

      expect(pending.nextSequence, 0);
      pending.enqueue('a', () async {}, record);
      pending.track(Future<void>.error(StateError('boom')), record);
      pending.enqueueBarrier(() async {}, record);
      expect(pending.nextSequence, 3);
      await pending.wait();

      expect(settled, unorderedEquals([(0, false), (1, true), (2, false)]));
    });

    test('an operation that supersedes a deferred one settles under its number, the superseded one never', () async {
      final pending = PendingOperations();
      final gate = Completer<void>();
      final settled = <(String, int)>[];

      pending.enqueue('k', () => gate.future, (sequence, _) => settled.add(('first', sequence)));
      pending.enqueue('k', () async {}, (sequence, _) => settled.add(('second', sequence)));
      pending.enqueue('k', () async {}, (sequence, _) => settled.add(('third', sequence)));
      gate.complete();
      await pending.wait();

      expect(settled, [('first', 0), ('third', 1)]);
    });

    test('the first operation for a key starts synchronously', () {
      final pending = PendingOperations();
      var started = false;

      pending.enqueue('k', () async => started = true, ignoreSettled);

      expect(started, isTrue);
    });

    test('operations on the same key run one at a time, in order', () async {
      final pending = PendingOperations();
      final firstGate = Completer<void>();
      final log = <String>[];

      pending.enqueue('k', () async {
        log.add('first:start');
        await firstGate.future;
        log.add('first:end');
      }, ignoreSettled);
      pending.enqueue('k', () async => log.add('second'), ignoreSettled);

      await Future<void>.delayed(Duration.zero);
      expect(log, ['first:start'], reason: 'second must wait for first');

      firstGate.complete();
      await pending.wait();
      expect(log, ['first:start', 'first:end', 'second']);
    });

    test('a deferred operation is superseded by a newer one for the same key', () async {
      final pending = PendingOperations();
      final firstGate = Completer<void>();
      final ran = <String>[];

      pending.enqueue('k', () => firstGate.future, ignoreSettled);
      pending.enqueue('k', () async => ran.add('second'), ignoreSettled);
      pending.enqueue('k', () async => ran.add('third'), ignoreSettled);

      firstGate.complete();
      await pending.wait();

      expect(ran, ['third']);
    });

    test('operations run one at a time, so a later key waits for an earlier one', () async {
      final pending = PendingOperations();
      final gate = Completer<void>();
      var otherStarted = false;

      pending.enqueue('a', () => gate.future, ignoreSettled);
      pending.enqueue('b', () async => otherStarted = true, ignoreSettled);

      expect(otherStarted, isFalse, reason: 'the storage has one queue');
      gate.complete();
      await pending.wait();
      expect(otherStarted, isTrue);
    });

    test('a throwing settlement callback does not rerun the operation or stall the queue', () async {
      final pending = PendingOperations();
      var runs = 0;
      var nextRan = false;
      final thrown = <Object>[];

      await runZonedGuarded(() async {
        pending.enqueue('k', () async => runs++, (sequence, failure) => throw StateError('callback'));
        pending.enqueue('next', () async => nextRan = true, ignoreSettled);
        await pending.wait();
      }, (error, stackTrace) => thrown.add(error));

      expect(runs, 1);
      expect(nextRan, isTrue);
      expect(pending.isNotEmpty, isFalse);
      expect(thrown.single, isA<StateError>().having((error) => error.message, 'message', 'callback'));
    });

    test('a failing operation does not block the next one for its key', () async {
      final pending = PendingOperations();
      final failed = <bool>[];
      var secondRan = false;

      pending.enqueue('k', () async => throw StateError('boom'), (sequence, failure) => failed.add(failure != null));
      pending.enqueue('k', () async => secondRan = true, (sequence, failure) => failed.add(failure != null));
      await pending.wait();

      expect(failed, [true, false]);
      expect(secondRan, isTrue);
      expect(pending.isNotEmpty, isFalse);
    });

    group('barrier', () {
      test('runs after in-flight and deferred operations enqueued before it, and before ones enqueued after', () async {
        final pending = PendingOperations();
        final log = <String>[];
        final gate = Completer<void>();

        pending.enqueue('a', () async {
          await gate.future;
          log.add('a1');
        }, ignoreSettled);
        pending.enqueue('a', () async => log.add('a2'), ignoreSettled); // deferred behind a1
        pending.enqueue('b', () async => log.add('b1'), ignoreSettled);
        pending.enqueueBarrier(() async => log.add('barrier'), ignoreSettled);
        pending.enqueue('a', () async => log.add('a3'), ignoreSettled); // after the barrier
        pending.enqueue('c', () async => log.add('c1'), ignoreSettled); // fresh key, after the barrier

        await Future<void>.delayed(Duration.zero);
        expect(log, isEmpty, reason: 'nothing else runs while a1 is still going');

        gate.complete();
        await pending.wait();

        expect(log, ['a1', 'a2', 'b1', 'barrier', 'a3', 'c1']);
        expect(pending.isNotEmpty, isFalse);
      });

      test('two barriers run in order and a barrier error is reported, not thrown', () async {
        final pending = PendingOperations();
        final log = <String>[];
        final failed = <bool>[];

        pending.enqueueBarrier(
          () async => throw StateError('boom'),
          (sequence, failure) => failed.add(failure != null),
        );
        pending.enqueueBarrier(() async => log.add('second'), (sequence, failure) => failed.add(failure != null));
        await pending.wait();

        expect(failed, [true, false]);
        expect(log, ['second']);
      });

      test('wait covers a barrier with nothing else pending', () async {
        final pending = PendingOperations();
        var ran = false;
        pending.enqueueBarrier(() async => ran = true, ignoreSettled);
        expect(pending.isNotEmpty, isTrue);
        await pending.wait();
        expect(ran, isTrue);
      });
    });

    group('track', () {
      test('wait covers a tracked operation and it is forgotten afterwards', () async {
        final pending = PendingOperations();
        final gate = Completer<void>();

        pending.track(gate.future, ignoreSettled);
        expect(pending.isNotEmpty, isTrue);

        final waiting = pending.wait();
        gate.complete();
        await waiting;
        expect(pending.isNotEmpty, isFalse);
      });

      test('tracked operations on one key run concurrently: nothing is deferred', () async {
        final pending = PendingOperations();
        final first = Completer<void>();
        final second = Completer<void>();

        pending.track(first.future, ignoreSettled);
        pending.track(second.future, ignoreSettled);

        second.complete();
        await Future<void>.delayed(Duration.zero);
        expect(pending.isNotEmpty, isTrue, reason: 'first still running');
        first.complete();
        await pending.wait();
      });

      test('a failing tracked operation is reported, not rethrown', () async {
        final pending = PendingOperations();
        final reported = <String>[];

        pending.track(Future<void>.error(StateError('boom')), (sequence, failure) => reported.add('${failure?.error}'));
        await pending.wait();

        expect(reported.single, 'Bad state: boom');
      });

      test('a tracked future that fails while the queue is busy is reported, not unhandled', () async {
        final pending = PendingOperations();
        final gate = Completer<void>();
        final reported = <Object?>[];
        final unhandled = <Object>[];

        await runZonedGuarded(() async {
          pending.enqueue('busy', () => gate.future, ignoreSettled);
          pending.track(Future<void>.error(StateError('boom')), (sequence, failure) => reported.add(failure?.error));
          // The error completes before the queue awaits the tracked future.
          await Future<void>.delayed(Duration.zero);
          gate.complete();
          await pending.wait();
        }, (error, stackTrace) => unhandled.add(error));

        expect(unhandled, isEmpty);
        expect(reported.single, isA<StateError>());
        expect(pending.isNotEmpty, isFalse);
      });

      test('a barrier waits for tracked operations enqueued before it', () async {
        final pending = PendingOperations();
        final gate = Completer<void>();
        final log = <String>[];

        pending.track(gate.future.then((_) => log.add('tracked')), ignoreSettled);
        pending.enqueueBarrier(() async => log.add('barrier'), ignoreSettled);

        await Future<void>.delayed(Duration.zero);
        expect(log, isEmpty);
        gate.complete();
        await pending.wait();
        expect(log, ['tracked', 'barrier']);
      });

      test('operations of one key settle in order even when they finish out of it', () async {
        final pending = PendingOperations();
        final first = Completer<void>();
        final settled = <int>[];

        pending
          ..track(first.future, (sequence, failure) => settled.add(sequence), keys: ['k'])
          ..track(Future<void>.value(), (sequence, failure) => settled.add(sequence), keys: ['k']);

        await pumpEventQueue();
        expect(settled, isEmpty, reason: 'the later one waits for the earlier to settle');
        first.complete();
        await pending.wait();
        expect(settled, [0, 1]);
      });
    });

    group('with operations over distinct keys running together', () {
      test('runs distinct keys at once, up to the limit, and one key in order', () async {
        final pending = PendingOperations(maxConcurrent: 2);
        final gates = {
          for (final key in ['a', 'b']) key: Completer<void>(),
        };
        final started = <String>[];

        pending
          ..enqueue('a', () async {
            started.add('a');
            await gates['a']!.future;
          }, ignoreSettled)
          ..enqueue('b', () async {
            started.add('b');
            await gates['b']!.future;
          }, ignoreSettled)
          ..enqueue('c', () async => started.add('c'), ignoreSettled)
          ..enqueueKeys(['a'], () async => started.add('a again'), ignoreSettled);

        expect(started, ['a', 'b'], reason: 'two run at once; c waits for a free place');
        gates['b']!.complete();
        await pumpEventQueue();
        expect(started, ['a', 'b', 'c'], reason: 'the operation over a still waits for the write of a');

        gates['a']!.complete();
        await pending.wait();
        expect(started, ['a', 'b', 'c', 'a again']);
      });

      test('wait over keys waits for those keys and for operations over every key, not for others', () async {
        final pending = PendingOperations(maxConcurrent: 2);
        final slow = Completer<void>();
        pending.enqueue('slow', () => slow.future, ignoreSettled);
        var fastDone = false;
        pending.enqueue('fast', () async => fastDone = true, ignoreSettled);

        await pending.wait(keys: ['fast']);
        expect(fastDone, isTrue);

        var barrierDone = false;
        pending.enqueueBarrier(() async => barrierDone = true, ignoreSettled);
        var waited = false;
        final waiting = pending.wait(keys: ['other']).then((_) => waited = true);
        await pumpEventQueue();
        expect(waited, isFalse, reason: 'an operation over every key covers every key, and it waits for slow');

        slow.complete();
        await waiting;
        expect(barrierDone, isTrue);
      });

      test('an operation over every key waits for every lane and holds back every later one', () async {
        final pending = PendingOperations(maxConcurrent: 4);
        final gate = Completer<void>();
        final log = <String>[];

        pending
          ..enqueue('a', () async {
            await gate.future;
            log.add('a');
          }, ignoreSettled)
          ..enqueueBarrier(() async => log.add('all'), ignoreSettled)
          ..enqueue('b', () async => log.add('b'), ignoreSettled);

        await pumpEventQueue();
        expect(log, isEmpty);
        gate.complete();
        await pending.wait();
        expect(log, ['a', 'all', 'b']);
      });
    });

    test('a batch of one key is not replaced by a later write of that key', () async {
      final pending = PendingOperations();
      final gate = Completer<void>();
      final log = <String>[];

      pending
        ..enqueue('a', () => gate.future, ignoreSettled)
        ..enqueueKeys(['a'], () async => log.add('batch'), ignoreSettled)
        ..enqueue('a', () async => log.add('write'), ignoreSettled);

      gate.complete();
      await pending.wait();
      expect(log, ['batch', 'write']);
    });

    test('rejects a limit below one', () {
      expect(() => PendingOperations(maxConcurrent: 0), throwsArgumentError);
    });
  });
}
