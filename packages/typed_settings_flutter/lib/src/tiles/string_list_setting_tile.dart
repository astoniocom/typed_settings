import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/count_badge.dart';
import 'package:typed_settings_flutter/src/widgets/list_picker_dialog.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';

/// A tile that shows the length of a `List<String>` setting and edits the
/// list in a dialog that adds, removes and reorders items.
///
/// The dialog trims the whitespace around a new item. While the list is one
/// the setting rejects, OK stays disabled and the dialog shows
/// [TypedSettingsLocalizations.validationMessage]. The items stay in the dialog.
class StringListSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const StringListSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<List<String>> setting;

  /// The title of the tile and the dialog; error messages name the setting
  /// by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return StringListTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      validator: setting.validate,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

/// Shows and edits [notifier] the way [StringListSettingTile] edits a setting.
///
/// [StringListSettingTile] binds this tile to a `Setting`. This tile stores
/// whatever [notifier] accepts. [validator] keeps a rejected list in
/// the dialog.
class StringListTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const StringListTile({
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
  final ValueNotifier<List<String>> notifier;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// Rejects a candidate list before it is stored. The dialog shows
  /// [TypedSettingsLocalizations.validationMessage] for the error and keeps
  /// the items. Accepts every list when omitted.
  final ValidationError? Function(List<String> value)? validator;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) {
        return SettingsTile(
          label: label,
          subtitle: subtitle,
          icon: icon,
          trailing: CountBadge(count: value.length),
          onTap: () => _showDialog(context, value),
        );
      },
    );
  }

  Future<void> _showDialog(BuildContext context, List<String> current) async {
    final check = validator;
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        final messages = TypedSettingsLocalizations.of(context);
        return ListPickerDialog(
          title: label,
          initial: current,
          parse: (text) => text.trim(),
          validateList: check == null
              ? null
              : (List<String> items) {
                  final error = check(items);
                  return error == null ? null : messages.validationMessage(error);
                },
        );
      },
    );

    if (result == null || !context.mounted) return;

    notifier.value = result;
  }
}
