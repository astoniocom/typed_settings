import 'package:meta/meta.dart';
import 'package:typed_settings/src/validation/validation_errors.dart';

/// A check a value must pass; `null` means the value is acceptable.
typedef ValueCheck<T> = ValidationError? Function(T value);

/// Validation policy of a setting: a pair of checks.
///
/// * The **invariant** holds for every value the setting exposes: values
///   decoded from storage (a failure falls back to the default), the
///   default value and values assigned through the setter or `commit`.
/// * The **write guard** is an additional check for persistence. It is
///   consulted only when a value is assigned (the setter, `commit`,
///   `validate`), before the invariant, and not when a stored value is
///   read: data stored before the guard existed stays readable.
///
/// Most settings need the invariant alone, which is what the default
/// constructor expresses; [SettingValidator.split] adds a write guard and
/// [SettingValidator.all] chains validators. The built-in checks
/// ([range], [pattern], [notNull], [noneOf]) produce the matching
/// `ValidationError` kinds.
///
/// The policy is always the two checks; [validateRead] and [validateWrite]
/// are not overridable, and the class is `base`, so a validator cannot
/// implement it and bypass them. Subclass (as a `base` or `final` class)
/// only to give a validator a name and fields (a schema, a limit) and
/// pass the checks to `super`.
base class SettingValidator<T> {
  /// One check that every value must pass: the invariant.
  const SettingValidator(ValueCheck<T> check) : this.split(invariant: check);

  /// The two checks apart; either may be omitted. [invariant] applies to
  /// every value, read or assigned; [writeGuard] to assigned values only,
  /// before [invariant].
  const SettingValidator.split({ValueCheck<T>? invariant, ValueCheck<T>? writeGuard})
    : _invariant = invariant,
      _writeGuard = writeGuard;

  /// Chains [validators]: the invariant runs their invariants in order,
  /// the write guard runs their write guards in order; the first error
  /// wins. So on write every guard is consulted before any invariant, as
  /// for a single validator.
  factory SettingValidator.all(List<SettingValidator<T>> validators) => SettingValidator.split(
    invariant: (value) => _firstError(validators, (validator) => validator._invariant?.call(value)),
    writeGuard: (value) => _firstError(validators, (validator) => validator._writeGuard?.call(value)),
  );

  /// Rejects a `null` value with a [RequiredValidationError]. For nullable
  /// settings whose `null` default must be replaced before persisting
  /// (combine with [SettingValidator.split] as a write guard) or must never
  /// be exposed at all.
  static SettingValidator<T> notNull<T>({String? debugDescription}) =>
      SettingValidator((value) => value == null ? RequiredValidationError(debugDescription: debugDescription) : null);

  /// Rejects a number outside `[min, max]` (both inclusive, either may be
  /// open) with a [RangeValidationError]. `null` passes; use [notNull] to
  /// reject it. An [ArgumentError] reports a range without bounds or with
  /// [min] above [max], which would let everything or nothing pass.
  static SettingValidator<N> range<N extends num?>({num? min, num? max, String? debugDescription}) {
    if (min == null && max == null) throw ArgumentError('range needs at least one bound');
    if (min != null && max != null && min > max) throw ArgumentError.value(min, 'min', 'must not exceed max ($max)');
    return SettingValidator((value) {
      if (value == null) return null;
      final tooSmall = min != null && value < min;
      final tooLarge = max != null && value > max;
      if (!tooSmall && !tooLarge) return null;
      return RangeValidationError(min: min, max: max, actual: value, debugDescription: debugDescription);
    });
  }

  /// Rejects a string that does not match [regExp] (via [RegExp.hasMatch])
  /// with a [PatternValidationError]. `null` passes; use [notNull] to
  /// reject it.
  static SettingValidator<S> pattern<S extends String?>(RegExp regExp, {String? debugDescription}) {
    return SettingValidator((value) {
      if (value == null || regExp.hasMatch(value)) return null;
      return PatternValidationError(pattern: regExp.pattern, actual: value, debugDescription: debugDescription);
    });
  }

  /// Rejects any of [values] (compared with `==`) with a
  /// [ForbiddenValueValidationError].
  static SettingValidator<T> noneOf<T>(Set<T> values, {String? debugDescription}) => SettingValidator(
    (value) => values.contains(value) ? ForbiddenValueValidationError(value, debugDescription: debugDescription) : null,
  );

  final ValueCheck<T>? _invariant;
  final ValueCheck<T>? _writeGuard;

  /// What a value read from storage must pass: the invariant alone; see
  /// the class documentation.
  @nonVirtual
  ValidationError? validateRead(T value) => _invariant?.call(value);

  /// What an assigned value must pass: the write guard, then the
  /// invariant. Returns the first error found.
  @nonVirtual
  ValidationError? validateWrite(T value) => _writeGuard?.call(value) ?? validateRead(value);

  static ValidationError? _firstError<T>(
    List<SettingValidator<T>> validators,
    ValidationError? Function(SettingValidator<T>) check,
  ) {
    for (final validator in validators) {
      final error = check(validator);
      if (error != null) return error;
    }
    return null;
  }
}
