import 'dart:ui';

import 'package:typed_settings/typed_settings.dart';

/// Rejects a [Locale] that is not one of [locales].
///
/// `null` passes, so the same validator fits `LocaleSetting` and
/// `LocaleNullableSetting`. Whether `null` is allowed at all is the
/// setting's concern: use [SettingValidator.notNull] to reject it.
///
/// Comparison is [Locale]'s own equality: language, script and region.
/// `Locale('en')` does not accept `Locale('en', 'US')`. List the locales
/// the application actually offers, the same list as `LocaleSettingTile`.
/// An empty list throws [ArgumentError].
final class LocaleValidator<T extends Locale?> extends SettingValidator<T> {
  /// Creates a validator that accepts only [locales].
  LocaleValidator(Iterable<Locale> locales, {String? debugDescription}) : this._(_require(locales), debugDescription);

  LocaleValidator._(this.locales, this.debugDescription) : super(_check(locales, debugDescription));

  /// The locales a value may be.
  final List<Locale> locales;

  /// Developer-facing explanation carried by a rejection.
  final String? debugDescription;

  static List<Locale> _require(Iterable<Locale> locales) {
    final list = List<Locale>.unmodifiable(locales);
    if (list.isEmpty) {
      throw ArgumentError.value(locales, 'locales', 'must list at least one locale');
    }
    return list;
  }

  static ValueCheck<T> _check<T extends Locale?>(List<Locale> locales, String? debugDescription) {
    return (value) {
      if (value == null || locales.contains(value)) return null;
      return ForbiddenValueValidationError(value, debugDescription: debugDescription);
    };
  }
}
