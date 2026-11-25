import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';

/// A tile that edits a `bool` setting with a switch.
///
/// A value the setting rejects goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile.
class BoolSwitchSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const BoolSwitchSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<bool> setting;

  /// The title of the tile; error messages name the setting by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return BoolSwitchTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

/// Shows and edits [notifier] the way [BoolSwitchSettingTile] edits a setting.
///
/// [BoolSwitchSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class BoolSwitchTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const BoolSwitchTile({
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
  final ValueNotifier<bool> notifier;

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
      builder: (context, value, _) => SwitchListTile(
        title: SettingsTile.title(label),
        subtitle: SettingsTile.subtitleText(subtitle),
        value: value,
        onChanged: (v) {
          notifier.value = v;
        },
        secondary: icon,
      ),
    );
  }
}
