import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/widgets/choice_menu_row.dart';

/// A tile that shows an enum setting and picks one of its
/// [EnumSetting.values] from a menu.
///
/// A value the setting rejects goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile.
class EnumSettingTile<T extends Enum> extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const EnumSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    this.nameBuilder,
    super.key,
  });

  /// The setting the tile shows and edits.
  final EnumSetting<T> setting;

  /// The title of the tile; error messages name the setting by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// The name of a value in the menu and on the tile; [EnumName.name] when
  /// null.
  final String Function(T value)? nameBuilder;

  @override
  Widget build(BuildContext context) {
    return EnumTile<T>(
      notifier: setting.editorView(context, label: label),
      label: label,
      values: setting.values,
      subtitle: subtitle,
      icon: icon,
      nameBuilder: nameBuilder,
    );
  }
}

/// Shows and edits [notifier] the way [EnumSettingTile] edits a setting.
///
/// [EnumSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class EnumTile<T extends Enum> extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const EnumTile({
    required this.notifier,
    required this.label,
    required this.values,
    this.subtitle,
    this.icon,
    this.nameBuilder,
    super.key,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<T> notifier;

  /// See [values] on the setting tile.
  final List<T> values;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// See [nameBuilder] on the setting tile.
  final String Function(T)? nameBuilder;

  String _name(T value) => nameBuilder?.call(value) ?? value.name;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) => ChoiceMenuRow<T>(
        value: value,
        options: values,
        nameOf: _name,
        onSelected: (option) => notifier.value = option,
        label: label,
        subtitle: subtitle,
        icon: icon,
      ),
    );
  }
}
