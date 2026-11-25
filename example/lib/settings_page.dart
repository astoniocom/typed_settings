import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_example/app_settings.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';
import 'package:typed_settings_json_schema_flutter/typed_settings_json_schema_flutter.dart';

/// Every tile of the library over [settings], grouped by kind. Subtitles
/// name the tile and the value its setting rejects.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.settings,
    super.key,
  });

  final AppSettings settings;

  static const _locales = [
    Locale('en'),
    Locale('ru'),
    Locale('de'),
  ];

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            _Section(
              title: 'Appearance',
              children: [
                ThemeSettingTile(
                  setting: settings.themeMode,
                  label: 'Theme',
                  subtitle: 'ThemeSettingTile',
                  icon: const Icon(Icons.brightness_6_outlined),
                ),
                ColorSettingTile(
                  setting: settings.accentColor,
                  label: 'Accent color',
                  subtitle: 'ColorSettingTile · red is rejected',
                  icon: const Icon(Icons.palette_outlined),
                ),
                ColorNullableSettingTile(
                  setting: settings.highlightColor,
                  label: 'Highlight color',
                  subtitle: 'ColorNullableSettingTile · red is rejected',
                  icon: const Icon(Icons.format_color_fill),
                ),
                LocaleNullableSettingTile(
                  setting: settings.language,
                  label: 'Language',
                  subtitle: 'LocaleNullableSettingTile',
                  icon: const Icon(Icons.language),
                  locales: _locales,
                  nullLabel: 'System',
                ),
                LocaleSettingTile(
                  setting: settings.fallbackLanguage,
                  label: 'Fallback language',
                  subtitle: 'LocaleSettingTile',
                  icon: const Icon(Icons.translate),
                  locales: _locales,
                ),
              ],
            ),
            _Section(
              title: 'Switches and choices',
              children: [
                BoolSwitchSettingTile(
                  setting: settings.notifications,
                  label: 'Notifications',
                  subtitle: 'BoolSwitchSettingTile',
                  icon: const Icon(Icons.notifications_outlined),
                ),
                BoolCheckboxSettingTile(
                  setting: settings.notifications,
                  label: 'Notifications',
                  subtitle: 'BoolCheckboxSettingTile · same setting',
                ),
                BoolNullableDropdownSettingTile(
                  setting: settings.autoSync,
                  label: 'Auto sync',
                  subtitle: 'BoolNullableDropdownSettingTile · off is rejected',
                  icon: const Icon(Icons.sync),
                ),
                BoolNullableCheckboxSettingTile(
                  setting: settings.autoSync,
                  label: 'Auto sync',
                  subtitle: 'BoolNullableCheckboxSettingTile · same setting',
                ),
                EnumSettingTile(
                  setting: settings.sortOrder,
                  label: 'Sort order',
                  subtitle: 'EnumSettingTile · oldest is rejected',
                  icon: const Icon(Icons.sort),
                ),
                EnumNullableSettingTile(
                  setting: settings.archiveSortOrder,
                  label: 'Archive sort order',
                  subtitle: 'EnumNullableSettingTile · oldest is rejected',
                  icon: const Icon(Icons.archive_outlined),
                ),
              ],
            ),
            _Section(
              title: 'Numbers',
              children: [
                IntSettingTile(
                  setting: settings.cacheSizeMb,
                  label: 'Cache size, MB',
                  subtitle: 'IntSettingTile · negative is rejected',
                  icon: const Icon(Icons.storage),
                ),
                IntNullableSettingTile(
                  setting: settings.retryLimit,
                  label: 'Retry limit',
                  subtitle: 'IntNullableSettingTile · 0 to 10',
                  icon: const Icon(Icons.replay),
                ),
                DoubleSettingTile(
                  setting: settings.volume,
                  label: 'Volume',
                  subtitle: 'DoubleSettingTile · above 0.9 is rejected',
                  icon: const Icon(Icons.volume_up_outlined),
                ),
                DoubleNullableSettingTile(
                  setting: settings.brightness,
                  label: 'Brightness',
                  subtitle: 'DoubleNullableSettingTile · below 0.1 is rejected',
                  icon: const Icon(Icons.light_mode_outlined),
                ),
              ],
            ),
            _Section(
              title: 'Date and time',
              children: [
                DateTimeSettingTile(
                  setting: settings.lastBackup,
                  label: 'Last backup',
                  subtitle: 'DateTimeSettingTile · the future is rejected',
                  icon: const Icon(Icons.backup_outlined),
                ),
                DateTimeNullableSettingTile(
                  setting: settings.lastSync,
                  label: 'Last sync',
                  subtitle: 'DateTimeNullableSettingTile · the future is rejected',
                  icon: const Icon(Icons.cloud_sync_outlined),
                ),
                DurationSettingTile(
                  setting: settings.syncInterval,
                  label: 'Sync interval',
                  subtitle: 'DurationSettingTile · under 15 minutes is rejected',
                  icon: const Icon(Icons.timer_outlined),
                ),
                DurationNullableSettingTile(
                  setting: settings.snooze,
                  label: 'Snooze',
                  subtitle: 'DurationNullableSettingTile · zero is rejected',
                  icon: const Icon(Icons.snooze),
                ),
                TimeOfDaySettingTile(
                  setting: settings.quietHoursStart,
                  label: 'Quiet hours start',
                  subtitle: 'TimeOfDaySettingTile',
                  icon: const Icon(Icons.bedtime_outlined),
                ),
                TimeOfDayNullableSettingTile(
                  setting: settings.alarm,
                  label: 'Alarm',
                  subtitle: 'TimeOfDayNullableSettingTile',
                  icon: const Icon(Icons.alarm),
                ),
              ],
            ),
            _Section(
              title: 'Text',
              children: [
                StringSettingTile(
                  setting: settings.nickname,
                  label: 'Nickname',
                  subtitle: 'StringSettingTile · 1 to 10 letters or digits',
                  icon: const Icon(Icons.person_outline),
                ),
                StringNullableSettingTile(
                  setting: settings.signature,
                  label: 'Signature',
                  subtitle: 'StringNullableSettingTile · "admin" is rejected',
                  icon: const Icon(Icons.draw_outlined),
                ),
              ],
            ),
            _Section(
              title: 'Collections',
              children: [
                StringListSettingTile(
                  setting: settings.tags,
                  label: 'Tags',
                  subtitle: 'StringListSettingTile · "spam" is rejected',
                  icon: const Icon(Icons.label_outline),
                ),
                IntListSettingTile(
                  setting: settings.luckyNumbers,
                  label: 'Lucky numbers',
                  subtitle: 'IntListSettingTile · 13 is rejected',
                  icon: const Icon(Icons.casino_outlined),
                ),
                MapSettingTile(
                  setting: settings.metadata,
                  label: 'Metadata',
                  subtitle: 'MapSettingTile · a "password" key is rejected',
                  icon: const Icon(Icons.data_object),
                ),
                MapNullableSettingTile(
                  setting: settings.profile,
                  label: 'Profile',
                  subtitle: 'MapNullableSettingTile',
                  icon: const Icon(Icons.badge_outlined),
                ),
                JsonSchemaMapSettingTile(
                  setting: settings.todoList,
                  label: 'Todo list',
                  subtitle: 'JsonSchemaMapSettingTile · edited by its schema',
                  icon: const Icon(Icons.checklist),
                ),
                JsonSchemaMapNullableSettingTile(
                  setting: settings.archivedTodoList,
                  label: 'Archived todo list',
                  subtitle: 'JsonSchemaMapNullableSettingTile',
                  icon: const Icon(Icons.inventory_2_outlined),
                ),
              ],
            ),
            _Section(
              title: 'Without a tile',
              children: [_LaunchCountTile(setting: settings.launchCount)],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
        ),
        Card.outlined(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: children),
        ),
      ],
    );
  }
}

/// A setting edited through its listeners and setter, as any widget can,
/// without a tile of the library. The setting is the `ValueListenable`.
class _LaunchCountTile extends StatelessWidget {
  const _LaunchCountTile({required this.setting});

  final Setting<int> setting;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: setting,
      builder: (context, value, _) => ListTile(
        leading: const Icon(Icons.rocket_launch_outlined),
        title: const Text('Launch count'),
        subtitle: Text('Counted at every start: $value'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              tooltip: 'Decrease',
              onPressed: value > 0 ? () => setting.value-- : null,
            ),
            IconButton(icon: const Icon(Icons.add), tooltip: 'Increase', onPressed: () => setting.value++),
            IconButton(icon: const Icon(Icons.refresh), tooltip: 'Reset to default', onPressed: setting.reset),
          ],
        ),
      ),
    );
  }
}
