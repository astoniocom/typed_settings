import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// [value] with [fractionDigits] digits after the decimal separator, in the
/// number format of the locale of [context] (`0.50`, `0,50`).
///
/// A locale `intl` has no number symbols for falls back to its language,
/// then to English. Number symbols ship with `intl`, so unlike dates they
/// need no initialization.
String formatFixed(BuildContext context, double value, int fractionDigits) {
  final locale = Intl.verifiedLocale(
    Localizations.localeOf(context).toLanguageTag(),
    NumberFormat.localeExists,
    onFailure: (_) => 'en',
  );
  return NumberFormat.decimalPatternDigits(locale: locale, decimalDigits: fractionDigits).format(value);
}
