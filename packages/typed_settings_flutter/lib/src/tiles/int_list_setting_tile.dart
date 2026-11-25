import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/count_badge.dart';
import 'package:typed_settings_flutter/src/widgets/list_picker_dialog.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';

/// A tile that shows the length of a `List<int>` setting and edits the list
/// in a dialog that adds, removes and reorders items.
///
/// An item outside [min] and [max] is not added. While the list is one the
/// setting rejects, OK stays disabled and the dialog shows
/// [TypedSettingsLocalizations.validationMessage]. The items stay in the dialog.
class IntListSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const IntListSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    this.min,
    this.max,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<List<int>> setting;

  /// The title of the tile and the dialog; error messages name the setting
  /// by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// The lowest item the dialog accepts; unbounded when null.
  final int? min;

  /// The highest item the dialog accepts; unbounded when null.
  final int? max;

  @override
  Widget build(BuildContext context) {
    return IntListTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      validator: setting.validate,
      subtitle: subtitle,
      icon: icon,
      min: min,
      max: max,
    );
  }
}

/// Shows and edits [notifier] the way [IntListSettingTile] edits a setting.
///
/// [IntListSettingTile] binds this tile to a `Setting`. This tile stores
/// whatever [notifier] accepts. [validator] keeps a rejected list in
/// the dialog.
class IntListTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const IntListTile({
    required this.notifier,
    required this.label,
    this.validator,
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
  final ValueNotifier<List<int>> notifier;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// Rejects a candidate list before it is stored. The dialog shows
  /// [TypedSettingsLocalizations.validationMessage] for the error and keeps
  /// the items. Accepts every list when omitted.
  final ValidationError? Function(List<int> value)? validator;

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
          trailing: CountBadge(count: value.length),
          onTap: () => _showDialog(context, value),
        );
      },
    );
  }

  Future<void> _showDialog(BuildContext context, List<int> current) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        final messages = TypedSettingsLocalizations.of(context);
        final lowest = min;
        final highest = max;
        final check = validator;
        return ListPickerDialog(
          title: label,
          initial: current,
          validateList: check == null
              ? null
              : (List<int> items) {
                  final error = check(items);
                  return error == null ? null : messages.validationMessage(error);
                },
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
          ],
          parse: (text) => int.parse(text.trim()),
          validate: (text) {
            final value = int.tryParse(text.trim());
            if (value == null) return messages.invalidInteger;
            if (lowest != null && value < lowest) return messages.rangeValue(min: lowest);
            if (highest != null && value > highest) return messages.rangeValue(max: highest);
            return null;
          },
        );
      },
    );
    if (result == null || !context.mounted) return;

    notifier.value = result;
  }
}
