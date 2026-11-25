import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/widgets/date_picking.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';
import 'package:typed_settings_flutter/src/widgets/value_chip.dart';

/// A tile that shows a [TimeOfDay] setting and edits it with the time
/// picker.
///
/// A value the setting rejects goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile.
class TimeOfDaySettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const TimeOfDaySettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<TimeOfDay> setting;

  /// The title of the tile; error messages name the setting by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return TimeOfDayTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

/// Shows and edits [notifier] the way [TimeOfDaySettingTile] edits a setting.
///
/// [TimeOfDaySettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class TimeOfDayTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const TimeOfDayTile({
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
  final ValueNotifier<TimeOfDay> notifier;

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
          trailing: ValueChip(value: formatTimeOfDay(context, value)),
          onTap: () => _pick(context, value),
        );
      },
    );
  }

  Future<void> _pick(BuildContext context, TimeOfDay current) async {
    final result = await pickTimeOfDay(context, current: current);
    if (result == null || !context.mounted) return;
    final picked = result.value;
    if (picked == null) return;
    notifier.value = picked;
  }
}
