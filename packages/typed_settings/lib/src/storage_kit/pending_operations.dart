import 'dart:async';

import 'package:meta/meta.dart';

/// What a failed operation threw.
typedef OperationFailure = ({Object error, StackTrace stackTrace});

/// Called once when an operation has finished, with the operation's
/// [sequence] number (see [PendingOperations]) and, when it failed, what
/// it threw; [failure] is `null` when it succeeded.
typedef OperationSettled = void Function(int sequence, OperationFailure? failure);

/// The asynchronous persistence operations of a storage, so the storage
/// can expose a [wait]-based `flush()`.
///
/// Storages update their in-memory state synchronously and persist in the
/// background. Each operation names the keys it persists: one key
/// ([enqueue]), several ([enqueueKeys]), or every key ([enqueueBarrier]).
/// Two operations that share a key run one after the other, in the order
/// they were enqueued, and an operation over every key runs after every
/// operation enqueued before it and before any enqueued after it.
/// Operations that share no key may run at the same time, up to
/// [maxConcurrent] at once, so that a slow write of one key does not hold
/// the others back. With the default of one, they run one at a time in
/// the order they were enqueued, except that a write held for its delay
/// (see [enqueue]) lets the operations over other keys go first.
///
/// A write enqueued for a key that already has a not-yet-started write
/// replaces it, when no operation over that key or over every key sits
/// between them. The replacement keeps the replaced write's number, so a
/// [wait] that covered the replaced write covers the one that carries its
/// effect. The replaced write never settles. A delay passed to [enqueue]
/// holds that write, unstarted, until it has passed without a
/// replacement; a replacement starts the wait again. [wait] does not sit
/// out a delay: it starts the held writes it covers, a replacement of one
/// of them is not held again, and then it waits for them.
///
/// [track] records an operation the storage has already started. Nothing
/// is deferred or merged: the backend ordered it itself, and it does not
/// count against [maxConcurrent]. A later operation over its keys still
/// waits for it.
///
/// [wait] covers exactly the operations enqueued before it was called, so
/// a key that is written continuously cannot keep it from completing;
/// given keys, only the operations over one of them or over every key.
///
/// Every operation settles exactly once, through the `onSettled` callback
/// it was handed over with. Errors of the operation are reported there and
/// never escape. A callback that throws is reported to the current zone
/// after the operation has left the queue, and the operation is not run
/// again.
///
/// Internal to `BackgroundPersistence`; backends use its `persist` and
/// `track` instead.
@internal
final class PendingOperations {
  /// The operations; at most [maxConcurrent] of those enqueued (not
  /// tracked) run at once.
  PendingOperations({this.maxConcurrent = 1}) {
    if (maxConcurrent < 1) throw ArgumentError.value(maxConcurrent, 'maxConcurrent', 'must be at least 1');
  }

  /// How many enqueued operations over distinct keys may run at once.
  final int maxConcurrent;

  int _nextSequence = 0;

  /// The operations that have not finished, in the order of their numbers.
  final List<_Op> _queue = [];

  final List<({int watermark, Set<String>? keys, Completer<void> done})> _waiters = [];

  /// How many enqueued (not tracked) operations are running.
  int _running = 0;

  /// Whether any persistence operation is still queued or running.
  bool get isNotEmpty => _queue.isNotEmpty;

  /// The number the next operation will get. [wait] covers the operations
  /// numbered below the value this has when [wait] is called.
  int get nextSequence => _nextSequence;

  /// Registers [future], an operation over [keys] (every key when `null`)
  /// that the storage has already started, so that [wait] covers it and
  /// its outcome goes to [onSettled] rather than a failure being an
  /// unhandled asynchronous error. Nothing is deferred or merged: this is
  /// for backends that order their own writes. A later operation over its
  /// keys waits for it like for any operation.
  void track(Future<void> future, OperationSettled onSettled, {Iterable<String>? keys}) {
    final op = _Op(sequence: _nextSequence++, keys: keys?.toSet(), onSettled: onSettled, tracked: future)
      ..started = true;
    _queue.add(op);
    unawaited(_settle(op, _await(future)));
  }

  /// Schedules [action] for [key]; see the class documentation for ordering
  /// and merging. The outcome goes to [onSettled]; errors are never thrown.
  ///
  /// Without [delay], the action starts in this call when nothing it must
  /// wait for is pending. With [delay], it stays unstarted until that time
  /// has passed without a later write of [key] replacing it. An
  /// [ArgumentError] when [delay] is zero or negative.
  void enqueue(String key, Future<void> Function() action, OperationSettled onSettled, {Duration? delay}) {
    _checkDelay(delay);
    for (var i = _queue.length - 1; i >= 0; i--) {
      final op = _queue[i];
      if (!op.touches({key})) continue;
      if (!op.started && op.replaceable) {
        op
          ..action = action
          ..onSettled = onSettled;
        _armDelay(op, delay);
        return;
      }
      break;
    }
    final op = _Op(sequence: _nextSequence++, keys: {key}, onSettled: onSettled, action: action, replaceable: true);
    _queue.add(op);
    _armDelay(op, delay);
  }

  void _checkDelay(Duration? delay) {
    if (delay != null && delay <= Duration.zero) {
      throw ArgumentError.value(delay, 'delay', 'must be positive');
    }
  }

  /// Holds [op] for [delay], or starts it when [delay] is null or a [wait]
  /// has released it. A hold already running is cancelled, so a
  /// replacement waits from now.
  void _armDelay(_Op op, Duration? delay) {
    op.delayTimer?.cancel();
    if (delay == null || op.released) {
      op.delayTimer = null;
      _schedule();
      return;
    }
    op.delayTimer = Timer(delay, () {
      op.delayTimer = null;
      _schedule();
    });
  }

  /// Starts every held write [wait] covers, and keeps a write that later
  /// replaces one of them from being held again: the waiter covers it. [keys]
  /// null releases all of them.
  void _releaseDelays(Set<String>? keys) {
    var started = false;
    for (final op in _queue) {
      if (op.started || !op.replaceable) continue;
      if (keys != null && !op.touches(keys)) continue;
      op.released = true;
      final timer = op.delayTimer;
      if (timer == null) continue;
      timer.cancel();
      op.delayTimer = null;
      started = true;
    }
    if (started) _schedule();
  }

  /// Schedules [action], which persists [keys] together: after every
  /// operation over one of them enqueued so far, and before any enqueued
  /// later. The outcome goes to [onSettled]; errors are never thrown.
  void enqueueKeys(Iterable<String> keys, Future<void> Function() action, OperationSettled onSettled) {
    _queue.add(_Op(sequence: _nextSequence++, keys: keys.toSet(), onSettled: onSettled, action: action));
    _schedule();
  }

  /// Schedules [action] to run after every operation enqueued so far has
  /// finished, and before any operation enqueued later starts. For bulk
  /// operations such as deleting a whole box, which have to be ordered
  /// against every key. The outcome goes to [onSettled]; errors are never
  /// thrown.
  void enqueueBarrier(Future<void> Function() action, OperationSettled onSettled) {
    _queue.add(_Op(sequence: _nextSequence++, keys: null, onSettled: onSettled, action: action));
    _schedule();
  }

  /// Completes when every operation enqueued before this call has finished;
  /// given [keys], every such operation over one of them or over every
  /// key. A write still held for its delay is started first, and then
  /// waited for: the delay is not sat out. A held write outside [keys]
  /// stays held. Operations enqueued afterwards are not waited for, so a
  /// key under continuous writes cannot starve a waiter; an operation that
  /// replaces a covered one is covered in its place (see the class
  /// documentation). Failures go to each operation's `onSettled` and do
  /// not make this future fail.
  Future<void> wait({Iterable<String>? keys}) {
    final scope = keys?.toSet();
    _releaseDelays(scope);
    final watermark = _nextSequence;
    if (!_pendingBelow(watermark, scope)) return Future<void>.value();
    final done = Completer<void>();
    _waiters.add((watermark: watermark, keys: scope, done: done));
    return done.future;
  }

  /// Starts every queued operation that nothing pending before it holds
  /// back, while fewer than [maxConcurrent] run.
  void _schedule() {
    for (var i = 0; i < _queue.length && _running < maxConcurrent; i++) {
      final op = _queue[i];
      if (op.started || op.delayTimer != null) continue;
      if (_queue.take(i).any((earlier) => earlier.touches(op.keys))) continue;
      op.started = true;
      _running++;
      unawaited(_settle(op, _run(op)));
    }
  }

  Future<OperationFailure?> _await(Future<void> future) async {
    // A failure before anything awaits this future would otherwise be an
    // unhandled asynchronous error. The await below still receives it.
    future.ignore();
    try {
      await future;
      return null;
      // Deliberately catches Errors too; see _run.
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stackTrace) {
      return (error: error, stackTrace: stackTrace);
    }
  }

  Future<OperationFailure?> _run(_Op op) async {
    try {
      if (!op.replaceable) {
        // An operation over several keys or every key is what a
        // synchronous burst (a `batch`, a `clear`) enqueues as it returns.
        // Yielding first keeps that burst from observing the operation's
        // own synchronous prefix before it has returned. A write of one
        // key still starts in the call that enqueued it.
        await Future<void>.value();
      }
      await op.action!();
      return null;
      // Deliberately catches Errors too: the operation runs detached from
      // the caller, so letting an Error escape would only produce an
      // unhandled asynchronous error that nothing attributes to a key.
      // Handing it to onSettled keeps it with its operation.
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stackTrace) {
      return (error: error, stackTrace: stackTrace);
    }
  }

  /// Waits for [outcome], then drops [op] from the queue before telling its
  /// caller, so that a callback that throws cannot leave it to be run
  /// again, and lets what it held back start.
  Future<void> _settle(_Op op, Future<OperationFailure?> outcome) async {
    final failure = await outcome;
    // Operations over a common key settle in the order they were handed
    // over even when they finish out of it (tracked ones may), so that a
    // late failure is not taken for the latest state of the key.
    await Future.wait([
      for (final earlier in _queue)
        if (earlier.sequence < op.sequence && earlier.touches(op.keys)) earlier.settled.future,
    ]);
    _queue.remove(op);
    if (op.tracked == null) _running--;
    try {
      op.onSettled(op.sequence, failure);
      // A throwing callback must not stop the queue. The error is the
      // callback's, so it is reported uncaught.
      // ignore: avoid_catches_without_on_clauses
    } catch (error, stackTrace) {
      Zone.current.handleUncaughtError(error, stackTrace);
    }
    op.settled.complete();
    _releaseWaiters();
    _schedule();
  }

  bool _pendingBelow(int watermark, Set<String>? keys) =>
      _queue.any((op) => op.sequence < watermark && op.touches(keys));

  void _releaseWaiters() {
    for (final waiter in List.of(_waiters)) {
      if (_pendingBelow(waiter.watermark, waiter.keys)) continue;
      _waiters.remove(waiter);
      waiter.done.complete();
    }
  }
}

class _Op {
  _Op({
    required this.sequence,
    required this.keys,
    required this.onSettled,
    this.action,
    this.tracked,
    this.replaceable = false,
  });

  final int sequence;

  /// Whether a later write of its key may replace it while it waits: a
  /// write of one key, not a batch that happens to hold one.
  final bool replaceable;

  /// The keys the operation persists; `null` for every key.
  final Set<String>? keys;

  Future<void> Function()? action;
  final Future<void>? tracked;
  OperationSettled onSettled;
  bool started = false;

  /// Set while this write is held for [PendingOperations.enqueue]'s delay.
  /// A write with one set is not started.
  Timer? delayTimer;

  /// Whether a [PendingOperations.wait] covers this write, so that a
  /// replacement is not held for the delay again.
  bool released = false;

  /// Completes once the operation has settled.
  final Completer<void> settled = Completer<void>();

  /// Whether this operation and one over [other] (every key when `null`)
  /// share a key.
  bool touches(Set<String>? other) {
    final own = keys;
    if (own == null || other == null) return true;
    return own.any(other.contains);
  }
}
