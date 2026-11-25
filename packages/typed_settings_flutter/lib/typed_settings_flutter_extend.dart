/// Building blocks for a setting tile of a new kind, so that it looks and
/// behaves like the tiles of this package.
///
/// Import this library when writing a tile or an editor dialog.
/// Applications that only use the tiles need
/// `package:typed_settings_flutter/typed_settings_flutter.dart`, which this
/// library re-exports.
///
/// * `SettingsTile`: the row every tile is built on.
/// * `ValueChip`: the current value at the end of a tile; `CountBadge`:
///   the size of a collection there.
/// * `DialogResult`: a dialog or menu result that tells "dismissed" apart
///   from a chosen `null`.
/// * `pickDateTime`, `pickTimeOfDay`: the date and time pickers of the
///   tiles, with an optional clear button; `PickDate` and `PickTime`
///   replace the Material pickers. `formatDateTime` and `formatTimeOfDay`
///   show a value the way those pickers do; `datePickerBounds`,
///   `dateKeepingTime` and `pickerWithClearButton` are the pieces they are
///   built from.
library;

export 'src/widgets/count_badge.dart';
export 'src/widgets/date_picking.dart';
export 'src/widgets/dialog_result.dart';
export 'src/widgets/settings_tile.dart';
export 'src/widgets/value_chip.dart';
export 'typed_settings_flutter.dart';
