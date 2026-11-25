import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';
import 'package:typed_settings_flutter/src/widgets/int_picker_dialog.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';
import 'package:typed_settings_flutter/src/widgets/value_chip.dart';

/// A tile that shows an `int` setting and edits it in a number field.
///
/// A value the setting rejects goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile.
class IntSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const IntSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    this.min,
    this.max,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<int> setting;

  /// The title of the tile and the dialog; error messages name the setting
  /// by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// The lowest value the dialog accepts; unbounded when null.
  final int? min;

  /// The highest value the dialog accepts; unbounded when null.
  final int? max;

  @override
  Widget build(BuildContext context) {
    return IntTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      subtitle: subtitle,
      icon: icon,
      min: min,
      max: max,
    );
  }
}

/// Shows and edits [notifier] the way [IntSettingTile] edits a setting.
///
/// [IntSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class IntTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const IntTile({
    required this.notifier,
    required this.label,
    this.subtitle,
    this.icon,
    this.min,
    this.max,
    super.key,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<int> notifier;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// See [min] on the setting tile.
  final int? min;

  /// See [max] on the setting tile.
  final int? max;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) {
        return SettingsTile(
          label: label,
          subtitle: subtitle,
          icon: icon,
          trailing: ValueChip(value: MaterialLocalizations.of(context).formatDecimal(value)),
          onTap: () => _showDialog(context, value),
        );
      },
    );
  }

  Future<void> _showDialog(BuildContext context, int current) async {
    final result = await showDialog<DialogResult<int?>>(
      context: context,
      builder: (context) => IntPickerDialog(
        title: label,
        initial: current,
        min: min,
        max: max,
      ),
    );
    final newValue = result?.value;
    if (newValue == null || !context.mounted) return;

    notifier.value = newValue;
  }
}
