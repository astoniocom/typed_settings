import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/widgets/color_picker_dialog.dart';
import 'package:typed_settings_flutter/src/widgets/color_preview.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';

/// A tile that shows a `Color?` setting and edits it in a color picker that
/// can also clear it to `null`.
///
/// A value the setting rejects goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile.
class ColorNullableSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const ColorNullableSettingTile({
    required this.setting,
    required this.label,
    this.presets,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<Color?> setting;

  /// The colors the picker offers, besides the current color when it is
  /// not among them. [Colors.primaries] when null.
  final List<Color>? presets;

  /// The title of the tile and the picker; error messages name the setting
  /// by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return ColorNullableTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      presets: presets,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

/// Shows and edits [notifier] the way [ColorNullableSettingTile] edits a setting.
///
/// [ColorNullableSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class ColorNullableTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const ColorNullableTile({
    required this.notifier,
    required this.label,
    this.presets,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<Color?> notifier;

  /// See [presets] on the setting tile.
  final List<Color>? presets;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color?>(
      valueListenable: notifier,
      builder: (context, color, _) {
        return SettingsTile(
          label: label,
          subtitle: subtitle,
          icon: icon,
          trailing: ColorPreview(color: color),
          onTap: () => _showColorPicker(context, color),
        );
      },
    );
  }

  Future<void> _showColorPicker(BuildContext context, Color? current) async {
    final result = await showDialog<DialogResult<Color?>>(
      context: context,
      builder: (context) => ColorPickerDialog(
        initial: current,
        allowNull: true,
        title: label,
        presets: presets ?? Colors.primaries,
      ),
    );
    if (result == null || !context.mounted) return;

    notifier.value = result.value;
  }
}
