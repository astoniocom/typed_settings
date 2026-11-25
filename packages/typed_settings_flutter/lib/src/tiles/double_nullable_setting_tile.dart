import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';
import 'package:typed_settings_flutter/src/widgets/double_picker_dialog.dart';
import 'package:typed_settings_flutter/src/widgets/number_format.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';
import 'package:typed_settings_flutter/src/widgets/value_chip.dart';

/// A tile that shows a `double?` setting and edits it with a slider between
/// [min] and [max], or clears it to `null`.
///
/// A value the setting rejects goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile.
class DoubleNullableSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const DoubleNullableSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.fractionDigits = 2,
    super.key,
  }) : assert(min < max, 'min must be less than max');

  /// The setting the tile shows and edits.
  final Setting<double?> setting;

  /// The title of the tile and the dialog; error messages name the setting
  /// by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// The lowest value the slider offers.
  final double min;

  /// The highest value the slider offers.
  final double max;

  /// The number of discrete steps of the slider; continuous when null.
  final int? divisions;

  /// The number of digits after the decimal point the tile shows.
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    return DoubleNullableTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      subtitle: subtitle,
      icon: icon,
      min: min,
      max: max,
      divisions: divisions,
      fractionDigits: fractionDigits,
    );
  }
}

/// Shows and edits [notifier] the way [DoubleNullableSettingTile] edits a setting.
///
/// [DoubleNullableSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class DoubleNullableTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const DoubleNullableTile({
    required this.notifier,
    required this.label,
    required this.min,
    required this.max,
    required this.fractionDigits,
    this.subtitle,
    this.icon,
    this.divisions,
    super.key,
  }) : assert(min < max, 'min must be less than max');

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<double?> notifier;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// See [min] on the setting tile.
  final double min;

  /// See [max] on the setting tile.
  final double max;

  /// See [divisions] on the setting tile.
  final int? divisions;

  /// See [fractionDigits] on the setting tile.
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) {
        return SettingsTile(
          label: label,
          subtitle: subtitle,
          icon: icon,
          onTap: () => _showDialog(context, value),
          trailing: value != null
              ? ValueChip(value: formatFixed(context, value, fractionDigits))
              : const Icon(Icons.edit),
        );
      },
    );
  }

  Future<void> _showDialog(BuildContext context, double? initial) async {
    final result = await showDialog<DialogResult<double?>>(
      context: context,
      builder: (context) => DoublePickerDialog(
        initial: initial,
        allowClear: true,
        min: min,
        max: max,
        divisions: divisions,
        fractionDigits: fractionDigits,
        title: label,
      ),
    );
    if (result == null || !context.mounted) return;

    notifier.value = result.value;
  }
}
