import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';

/// A tile that picks a [ThemeMode] with a segmented button: light, system,
/// dark.
///
/// Each segment is an icon. Its tooltip is the name on the semantics
/// node a screen reader visits, and the icon carries the same semantic label.
/// A value the setting rejects goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile.
class ThemeSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const ThemeSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    this.lightLabel,
    this.systemLabel,
    this.darkLabel,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<ThemeMode> setting;

  /// The title of the tile; error messages name the setting by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// The name of [ThemeMode.light].
  /// [TypedSettingsLocalizations.lightThemeLabel] when null.
  final String? lightLabel;

  /// The name of [ThemeMode.system].
  /// [TypedSettingsLocalizations.systemThemeLabel] when null.
  final String? systemLabel;

  /// The name of [ThemeMode.dark].
  /// [TypedSettingsLocalizations.darkThemeLabel] when null.
  final String? darkLabel;

  @override
  Widget build(BuildContext context) {
    return ThemeTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      subtitle: subtitle,
      icon: icon,
      lightLabel: lightLabel,
      systemLabel: systemLabel,
      darkLabel: darkLabel,
    );
  }
}

/// Shows and edits [notifier] the way [ThemeSettingTile] edits a setting.
///
/// [ThemeSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class ThemeTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const ThemeTile({
    required this.notifier,
    required this.label,
    this.subtitle,
    this.icon,
    this.lightLabel,
    this.systemLabel,
    this.darkLabel,
    super.key,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<ThemeMode> notifier;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// See [ThemeSettingTile.lightLabel].
  final String? lightLabel;

  /// See [ThemeSettingTile.systemLabel].
  final String? systemLabel;

  /// See [ThemeSettingTile.darkLabel].
  final String? darkLabel;

  @override
  Widget build(BuildContext context) {
    final messages = TypedSettingsLocalizations.of(context);
    final light = lightLabel ?? messages.lightThemeLabel;
    final system = systemLabel ?? messages.systemThemeLabel;
    final dark = darkLabel ?? messages.darkThemeLabel;
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) => SettingsTile(
        label: label,
        subtitle: subtitle,
        icon: icon,
        trailing: SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode, semanticLabel: light),
              tooltip: light,
            ),
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.contrast, semanticLabel: system),
              tooltip: system,
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode, semanticLabel: dark),
              tooltip: dark,
            ),
          ],
          selected: {value},
          onSelectionChanged: (v) => notifier.value = v.first,
        ),
      ),
    );
  }
}
