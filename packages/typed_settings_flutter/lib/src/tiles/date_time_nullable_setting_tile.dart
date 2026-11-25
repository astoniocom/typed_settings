import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/widgets/date_picking.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';
import 'package:typed_settings_flutter/src/widgets/value_chip.dart';

/// A tile that shows a `DateTime?` setting and edits it with the date
/// picker, then the time picker when [pickTime].
///
/// While the setting holds a value, the date picker shows a button that
/// clears it to `null`. A value the setting rejects goes to the
/// [SettingsErrorHandler] of the [SettingsErrorHandlerProvider] above the
/// tile.
class DateTimeNullableSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const DateTimeNullableSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    this.firstDate,
    this.lastDate,
    this.pickTime = true,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<DateTime?> setting;

  /// The title of the tile; error messages name the setting by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// The earliest date the picker offers. Ten years before today when null.
  /// A current value earlier than this is still offered, so confirming the
  /// date the picker opens on does not replace it with this bound.
  final DateTime? firstDate;

  /// The latest date the picker offers. Ten years after today when null.
  /// A current value later than this is still offered, so confirming the
  /// date the picker opens on does not replace it with this bound.
  final DateTime? lastDate;

  /// Whether the tile picks a time of day after the date. Without it the
  /// picked value is the start of the day. Cancelling the time picker keeps
  /// the previous time of day on the date that was confirmed, or the time
  /// the picker opened on when the value was null.
  final bool pickTime;

  @override
  Widget build(BuildContext context) {
    return DateTimeNullableTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      subtitle: subtitle,
      icon: icon,
      firstDate: firstDate,
      lastDate: lastDate,
      pickTime: pickTime,
    );
  }
}

/// Shows and edits [notifier] the way [DateTimeNullableSettingTile] edits a setting.
///
/// [DateTimeNullableSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class DateTimeNullableTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const DateTimeNullableTile({
    required this.notifier,
    required this.label,
    required this.pickTime,
    this.subtitle,
    this.icon,
    this.firstDate,
    this.lastDate,
    super.key,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<DateTime?> notifier;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// See [firstDate] on the setting tile.
  final DateTime? firstDate;

  /// See [lastDate] on the setting tile.
  final DateTime? lastDate;

  /// See [pickTime] on the setting tile.
  final bool pickTime;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) {
        return SettingsTile(
          label: label,
          subtitle: subtitle,
          icon: icon,
          onTap: () => _pick(context, value),
          trailing: value != null
              ? ValueChip(value: formatDateTime(context, value, withTime: pickTime))
              : const Icon(Icons.edit),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context, DateTime? current) async {
    final result = await pickDateTime(
      context,
      current: current,
      firstDate: firstDate,
      lastDate: lastDate,
      pickTime: pickTime,
      allowClear: current != null,
    );
    if (result == null || !context.mounted) return;
    notifier.value = result.value;
  }
}
