import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';
import 'package:typed_settings_flutter/src/widgets/duration_picker_dialog.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';
import 'package:typed_settings_flutter/src/widgets/value_chip.dart';

/// A tile that shows a `Duration?` setting and edits it in hours, minutes
/// and seconds, or clears it to `null`.
///
/// The chip uses [TypedSettingsLocalizations.durationLabel].
///
/// A value the setting rejects goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile.
class DurationNullableSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const DurationNullableSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<Duration?> setting;

  /// The title of the tile and the dialog; error messages name the setting
  /// by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return DurationNullableTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

/// Shows and edits [notifier] the way [DurationNullableSettingTile] edits a setting.
///
/// [DurationNullableSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class DurationNullableTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const DurationNullableTile({
    required this.notifier,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<Duration?> notifier;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) {
        return SettingsTile(
          label: label,
          subtitle: subtitle,
          icon: icon,
          trailing: value != null
              ? ValueChip(value: TypedSettingsLocalizations.of(context).durationLabel(value))
              : const Icon(Icons.edit),
          onTap: () => _showDialog(context, value),
        );
      },
    );
  }

  Future<void> _showDialog(BuildContext context, Duration? current) async {
    final result = await showDialog<DialogResult<Duration?>>(
      context: context,
      builder: (context) => DurationPickerDialog(
        initial: current,
        title: label,
        allowClear: true,
      ),
    );
    if (result == null || !context.mounted) return;

    notifier.value = result.value;
  }
}
