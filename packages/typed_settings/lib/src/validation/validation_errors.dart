import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:typed_settings/src/foundation/build_mode.dart';

/// Why a value was rejected by a `SettingValidator`.
///
/// A plain value object: compared structurally, never thrown by itself
/// (the setter wraps it in a `SettingValidationException`). Deliberately
/// not sealed so that applications and other packages can add their own
/// kinds: subclass (as a `base` or `final` class), add fields and list
/// them in [props]. It is `base`, so a kind cannot implement it and miss
/// the structural comparison. How an error is
/// presented to the user is the application's concern; [debugDescription]
/// is for developers only.
@immutable
base class ValidationError {
  /// Creates an error; [debugDescription] is free text for developers.
  const ValidationError({
    this.debugDescription,
  });

  /// Developer-facing explanation; not meant to be shown to users. It is
  /// what [toString] shows outside debug builds, so keep the rejected
  /// value out of it.
  final String? debugDescription;

  /// The fields that define this error's identity, used by [==],
  /// [hashCode] and, in debug builds, [toString]. Collections are compared
  /// deeply. Override to append the subclass's fields.
  @protected
  List<Object?> get props => [debugDescription];

  static const _equality = DeepCollectionEquality();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationError && other.runtimeType == runtimeType && _equality.equals(other.props, props);

  @override
  int get hashCode => Object.hash(runtimeType, _equality.hash(props));

  /// For developers: [describe] with [props] in debug builds, and with
  /// only [debugDescription] outside them, since props may hold the
  /// rejected value, which can be a secret or personal data.
  @override
  String toString() => describe(includeData: isDebugBuild);

  /// This error as text: the concrete type in debug builds (elsewhere type
  /// names are minified, and it reads `ValidationError`), followed by
  /// [props] when [includeData] is set and by [debugDescription] alone
  /// otherwise.
  String describe({required bool includeData}) =>
      '${isDebugBuild ? _debugTypeName(this) : 'ValidationError'}(${includeData ? props.join(', ') : debugDescription ?? ''})';
}

/// `runtimeType` as a string; only called in debug mode, where type names
/// are not minified.
String _debugTypeName(Object object) => object.runtimeType.toString();

/// A value is missing where one is required.
final class RequiredValidationError extends ValidationError {
  /// Creates the error.
  const RequiredValidationError({super.debugDescription});
}

/// [actual] lies outside `[min, max]`; a `null` bound is open.
///
/// The numbers are `num`s whatever the setting holds: an error of an
/// `int` setting and one of a `double` setting are the same kind of
/// error, matched with `is RangeValidationError`.
final class RangeValidationError extends ValidationError {
  /// Creates the error for [actual] outside `[min, max]`; at least one
  /// bound should be given.
  const RangeValidationError({
    required this.actual,
    this.min,
    this.max,
    super.debugDescription,
  });

  /// Lowest allowed value, inclusive; `null` when unbounded below.
  final num? min;

  /// Highest allowed value, inclusive; `null` when unbounded above.
  final num? max;

  /// The rejected value.
  final num actual;

  @override
  List<Object?> get props => [min, max, actual, debugDescription];
}

/// [actual] does not match [pattern].
final class PatternValidationError extends ValidationError {
  /// Creates the error for [actual] not matching [pattern].
  const PatternValidationError({
    required this.pattern,
    required this.actual,
    super.debugDescription,
  });

  /// The pattern the value had to match, as its source string.
  final String pattern;

  /// The rejected value.
  final String actual;

  @override
  List<Object?> get props => [pattern, actual, debugDescription];
}

/// [value] is specifically disallowed.
final class ForbiddenValueValidationError<T> extends ValidationError {
  /// Creates the error for the disallowed [value].
  const ForbiddenValueValidationError(this.value, {super.debugDescription});

  /// The rejected value.
  final T value;

  @override
  List<Object?> get props => [value, debugDescription];
}
