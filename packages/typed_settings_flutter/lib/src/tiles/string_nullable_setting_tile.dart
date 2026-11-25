import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';
import 'package:typed_settings_flutter/src/widgets/string_edit_dialog.dart';
import 'package:typed_settings_flutter/src/widgets/value_chip.dart';

/// A tile that shows a `String?` setting and edits it in a text field.
///
/// Submitting an empty text stores `null`, so the tile cannot store an
/// empty string. While the text is one the setting rejects, the field shows
/// [TypedSettingsLocalizations.validationMessage] for that error. The
/// message does not include the rejected text. The dialog does not submit it.
class StringNullableSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const StringNullableSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<String?> setting;

  /// The title of the tile and the dialog; error messages name the setting
  /// by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return StringNullableTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      validator: setting.validate,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

/// Shows and edits [notifier] the way [StringNullableSettingTile] edits a setting.
///
/// [StringNullableSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class StringNullableTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const StringNullableTile({
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
  final ValueNotifier<String?> notifier;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// Rejects a candidate before it is stored. The field shows
  /// [TypedSettingsLocalizations.validationMessage] for the error.
  /// Accepts every value when omitted.
  final ValidationError? Function(String? value)? validator;

  static String? _stored(String text) => text.isEmpty ? null : text;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) => SettingsTile(
        label: label,
        subtitle: subtitle,
        icon: icon,
        trailing: value == null ? const Icon(Icons.edit) : ValueChip(value: value),
        onTap: () => _showDialog(context, value),
      ),
    );
  }

  Future<void> _showDialog(BuildContext context, String? current) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final messages = TypedSettingsLocalizations.of(context);
        return StringEditDialog(
          title: label,
          initial: current ?? '',
          validator: (text) {
            final error = validator?.call(_stored(text));
            return error == null ? null : messages.validationMessage(error);
          },
        );
      },
    );
    if (result == null || !context.mounted) return;

    notifier.value = _stored(result);
  }
}
