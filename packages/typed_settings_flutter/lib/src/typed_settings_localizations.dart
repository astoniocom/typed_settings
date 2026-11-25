import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show MaterialLocalizations;
import 'package:typed_settings/typed_settings.dart';

/// Text of the setting editors that [MaterialLocalizations] does not have.
///
/// OK, Cancel, the hour and minute labels, and the delete tooltip come
/// from [MaterialLocalizations]. Clearing a value uses [clearValueLabel],
/// and clearing a color uses [clearColorLabel]: Material's clear tooltip
/// talks about text. The move-up and move-down tooltips come from
/// [WidgetsLocalizations]. [of] returns these
/// English strings when the tree provides no [TypedSettingsLocalizations].
/// An application that translates the remaining editor text subclasses this
/// class and installs the subclass with a [LocalizationsDelegate] of this
/// type. [of] then returns that subclass.
class TypedSettingsLocalizations {
  /// English text.
  const TypedSettingsLocalizations();

  /// The editors' strings from the closest [Localizations], or the English
  /// text when the application has not provided any.
  // A constructor would allocate a new instance. This returns the one the
  // tree already holds.
  // ignore: prefer_constructors_over_static_methods
  static TypedSettingsLocalizations of(BuildContext context) {
    return Localizations.of<TypedSettingsLocalizations>(context, TypedSettingsLocalizations) ??
        const TypedSettingsLocalizations();
  }

  /// The message for a text that is not an integer.
  String get invalidInteger => 'Enter a valid integer';

  /// The message for a missing value.
  String get requiredValue => 'Enter a value';

  /// The message for a text that does not match the required format.
  String get invalidFormat => 'Enter a value in the required format';

  /// The message for a value that is specifically disallowed.
  String get valueNotAllowed => 'This value is not allowed';

  /// The message for a rejected value the other sentences do not cover.
  String get invalidValue => 'Enter a valid value';

  /// The message for a number outside the given bounds. An open bound is omitted.
  ///
  /// [invalidValue] when neither bound is set.
  String rangeValue({num? min, num? max}) {
    if (min != null && max != null) return 'Enter a value from $min to $max';
    if (min != null) return 'Minimum value is $min';
    if (max != null) return 'Maximum value is $max';
    return invalidValue;
  }

  /// The message a field and the default error handler show for [error].
  ///
  /// The rejected value stays out of it: a validation error may hold that
  /// value, and it may be a secret. A kind this class does not know uses
  /// [invalidValue]. Override to word a kind of your own.
  String validationMessage(ValidationError error) => switch (error) {
    RequiredValidationError() => requiredValue,
    PatternValidationError() => invalidFormat,
    ForbiddenValueValidationError() => valueNotAllowed,
    RangeValidationError(:final min, :final max) => rangeValue(min: min, max: max),
    _ => invalidValue,
  };

  /// The label of the lower bound under the field.
  String minimumHint(int minimum) => 'min: $minimum';

  /// The label of the upper bound under the field.
  String maximumHint(int maximum) => 'max: $maximum';

  /// The message when text is not valid JSON.
  ///
  /// [offset] is the character index the parser reported, counting from 0.
  /// It is omitted when the parser did not report one.
  String invalidJson(int? offset) => offset == null ? 'Invalid JSON' : 'Invalid JSON at position $offset';

  /// The message when JSON text is not an object.
  String get jsonMustBeObject => 'JSON value must be an object';

  /// The message when a JSON object key is not a string.
  String get jsonKeysMustBeStrings => 'JSON object keys must be strings';

  /// The tab that edits a map through a form.
  String get editorTab => 'Editor';

  /// The tab that edits a map as JSON text.
  String get rawJsonTab => 'Raw JSON';

  /// The message when a form cannot be built for the current value.
  String get unableToBuildEditor => 'Unable to build an editor for this value.';

  /// The label of the field that adds a list item.
  String get newListValue => 'New value';

  /// The message shown while a list has no items.
  String get noListItems => 'No items yet';

  /// How many items the list holds.
  String listItemCount(int count) => count == 1 ? '1 item' : '$count items';

  /// The name of `true` on a nullable bool tile. Material has no such label.
  String get enabledLabel => 'Enabled';

  /// The name of `false` on a nullable bool tile. Material has no such label.
  String get disabledLabel => 'Disabled';

  /// The name of a stored `null` on a nullable tile. Material has no such label.
  String get notSetLabel => 'Not set';

  /// The name of the light theme segment. Material has no theme-mode names.
  String get lightThemeLabel => 'Light';

  /// The name of the system theme segment. Material has no theme-mode names.
  String get systemThemeLabel => 'System';

  /// The name of the dark theme segment. Material has no theme-mode names.
  String get darkThemeLabel => 'Dark';

  /// The label of the hex color field. Material has no color field.
  String get colorHexLabel => 'Hex';

  /// The message for a hex color that is not `#RRGGBB` or `#AARRGGBB`.
  String get invalidColor => 'Enter #RRGGBB or #AARRGGBB';

  /// The label of the button that clears a stored value, and the tooltip of
  /// that icon. Material's clear tooltip talks about text.
  String get clearValueLabel => 'Clear value';

  /// The tooltip of the button that clears a color. Material's clear
  /// tooltip talks about text.
  String get clearColorLabel => 'Clear color';

  /// The label of the seconds field.
  ///
  /// Hours and minutes use [MaterialLocalizations.timePickerHourLabel] and
  /// [MaterialLocalizations.timePickerMinuteLabel].
  String get secondsLabel => 'Seconds';

  /// The short hour unit on a duration chip. Material has no such unit.
  String get durationHourUnit => 'h';

  /// The short minute unit on a duration chip. Material has no such unit.
  String get durationMinuteUnit => 'm';

  /// The short second unit on a duration chip. Material has no such unit.
  String get durationSecondUnit => 's';

  /// [duration] on a tile chip: `1h 05m 03s`, `5m 03s`, or `3s`.
  ///
  /// A larger unit that is zero is left out. Minutes and seconds are two
  /// digits when a larger unit is shown. The dialog shows `01:05:03` instead.
  String durationLabel(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    String two(int value) => value.toString().padLeft(2, '0');
    if (hours > 0) {
      return '$hours$durationHourUnit ${two(minutes)}$durationMinuteUnit ${two(seconds)}$durationSecondUnit';
    }
    if (minutes > 0) return '$minutes$durationMinuteUnit ${two(seconds)}$durationSecondUnit';
    return '$seconds$durationSecondUnit';
  }
}
