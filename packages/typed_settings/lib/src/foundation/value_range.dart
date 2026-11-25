import 'package:meta/meta.dart';

/// A pair of values, the start and the end of a range.
///
/// Both ends are present. A missing range is the `null` of a nullable
/// setting, not a range with one end omitted. Equality is [==] of the
/// ends.
@immutable
final class ValueRange<T extends Object> {
  /// A range from [start] to [end].
  const ValueRange({required this.start, required this.end});

  /// The first end.
  final T start;

  /// The second end.
  final T end;

  @override
  bool operator ==(Object other) => other is ValueRange<T> && start == other.start && end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'ValueRange($start, $end)';
}
