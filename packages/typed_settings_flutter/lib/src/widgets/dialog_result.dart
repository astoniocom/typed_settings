import 'package:flutter/foundation.dart';

/// A dialog or menu result, so `null` (dismissed) stays distinct from a
/// result whose value is null (`DialogResult(null)`).
///
/// Equality is by the wrapped [value], so a `PopupMenuButton.initialValue`
/// built as `DialogResult(current)` matches the corresponding item.
@immutable
class DialogResult<T> {
  /// Wraps [value].
  const DialogResult(this.value);

  /// The wrapped result, which may itself be null.
  final T value;

  @override
  String toString() => 'DialogResult($value)';

  @override
  bool operator ==(Object other) => identical(this, other) || other is DialogResult<T> && value == other.value;

  @override
  int get hashCode => value.hashCode;
}
