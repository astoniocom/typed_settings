import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';
import 'package:typed_settings_flutter/src/widgets/string_edit_dialog.dart';
import 'package:typed_settings_flutter/src/widgets/value_chip.dart';

/// A tile that shows a `String` setting and edits it in a text field.
///
/// While the text is one the setting rejects, the field shows
/// [TypedSettingsLocalizations.validationMessage] for that error. The
/// message does not include the rejected text. The dialog does not submit it.
class StringSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const StringSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<String> setting;

  /// The title of the tile and the dialog; error messages name the setting
  /// by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return StringTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      validator: setting.validate,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

/// Shows and edits [notifier] the way [StringSettingTile] edits a setting.
///
/// [StringSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class StringTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const StringTile({
    required this.notifier,
    required this.label,
    this.validator,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<String> notifier;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// Rejects a candidate before it is stored. The field shows
  /// [TypedSettingsLocalizations.validationMessage] for the error.
  /// Accepts every value when omitted.
  final ValidationError? Function(String value)? validator;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) => SettingsTile(
        label: label,
        subtitle: subtitle,
        icon: icon,
        trailing: value.isEmpty ? const Icon(Icons.edit) : ValueChip(value: value),
        onTap: () => _showDialog(context, value),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context, String current) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final messages = TypedSettingsLocalizations.of(context);
        return StringEditDialog(
          title: label,
          initial: current,
          validator: (text) {
            final error = validator?.call(text);
            return error == null ? null : messages.validationMessage(error);
          },
        );
      },
    );
    if (result == null || !context.mounted) return;

    notifier.value = result;
  }
}
