import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_example/todo_schema.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';
import 'package:typed_settings_json_schema/typed_settings_json_schema.dart';

enum SortOrder { newest, oldest, name }

/// The settings of the application over one storage, which it owns. Each
/// setting is created on first use and owned, so that [close] releases
/// them all.
///
/// Most settings reject one value, so that the error handler of the
/// settings page can be tried out; the page says which.
class AppSettings {
  AppSettings({required this.storage});

  final SettingsStorage storage;

  final _settings = SettingsOwner();

  /// Disposes the settings and closes [storage]; the future fails like
  /// [SettingsStorage.close].
  Future<void> close() {
    _settings.dispose();
    return storage.close();
  }

  // Appearance

  late final EnumSetting<ThemeMode> themeMode = _settings.own(
    EnumSetting(storage: storage, key: 'theme_mode', values: ThemeMode.values, defaultValue: ThemeMode.system),
  );

  late final ColorSetting accentColor = _settings.own(
    ColorSetting(storage: storage, key: 'accent_color', defaultValue: Colors.indigo, validator: _notRed()),
  );

  late final ColorNullableSetting highlightColor = _settings.own(
    ColorNullableSetting(storage: storage, key: 'highlight_color', validator: _notRed()),
  );

  late final LocaleNullableSetting language = _settings.own(
    LocaleNullableSetting(storage: storage, key: 'language'),
  );

  late final LocaleSetting fallbackLanguage = _settings.own(
    LocaleSetting(storage: storage, key: 'fallback_language', defaultValue: const Locale('en')),
  );

  // Switches and choices

  late final BoolSetting notifications = _settings.own(
    BoolSetting(storage: storage, key: 'notifications', defaultValue: true),
  );

  late final BoolNullableSetting autoSync = _settings.own(
    BoolNullableSetting(
      storage: storage,
      key: 'auto_sync',
      defaultValue: true,
      validator: SettingValidator.noneOf({false}, debugDescription: 'auto sync cannot be turned off'),
    ),
  );

  late final EnumSetting<SortOrder> sortOrder = _settings.own(
    EnumSetting(
      storage: storage,
      key: 'sort_order',
      values: SortOrder.values,
      defaultValue: SortOrder.newest,
      validator: SettingValidator.noneOf({SortOrder.oldest}),
    ),
  );

  late final EnumNullableSetting<SortOrder> archiveSortOrder = _settings.own(
    EnumNullableSetting(
      storage: storage,
      key: 'archive_sort_order',
      values: SortOrder.values,
      validator: SettingValidator.noneOf({SortOrder.oldest}),
    ),
  );

  // Numbers

  late final IntSetting cacheSizeMb = _settings.own(
    IntSetting(storage: storage, key: 'cache_size_mb', defaultValue: 64, validator: SettingValidator.range(min: 0)),
  );

  late final IntNullableSetting retryLimit = _settings.own(
    IntNullableSetting(storage: storage, key: 'retry_limit', validator: SettingValidator.range(min: 0, max: 10)),
  );

  late final DoubleSetting volume = _settings.own(
    DoubleSetting(storage: storage, key: 'volume', defaultValue: 0.5, validator: SettingValidator.range(max: 0.9)),
  );

  late final DoubleNullableSetting brightness = _settings.own(
    DoubleNullableSetting(storage: storage, key: 'brightness', validator: SettingValidator.range(min: 0.1)),
  );

  // Date and time

  late final DateTimeSetting lastBackup = _settings.own(
    DateTimeSetting(
      storage: storage,
      key: 'last_backup',
      defaultValue: DateTime(2026),
      validator: _reject((value) => value.isAfter(DateTime.now()), 'a backup cannot be in the future'),
    ),
  );

  late final DateTimeNullableSetting lastSync = _settings.own(
    DateTimeNullableSetting(
      storage: storage,
      key: 'last_sync',
      validator: _reject((value) => value != null && value.isAfter(DateTime.now()), 'a sync cannot be in the future'),
    ),
  );

  late final DurationSetting syncInterval = _settings.own(
    DurationSetting(
      storage: storage,
      key: 'sync_interval',
      defaultValue: const Duration(hours: 1),
      validator: _reject((value) => value < const Duration(minutes: 15), 'at least 15 minutes'),
    ),
  );

  late final DurationNullableSetting snooze = _settings.own(
    DurationNullableSetting(
      storage: storage,
      key: 'snooze',
      validator: _reject((value) => value == Duration.zero, 'a snooze must last'),
    ),
  );

  late final TimeOfDaySetting quietHoursStart = _settings.own(
    TimeOfDaySetting(storage: storage, key: 'quiet_hours_start', defaultValue: const TimeOfDay(hour: 22, minute: 0)),
  );

  late final TimeOfDayNullableSetting alarm = _settings.own(
    TimeOfDayNullableSetting(storage: storage, key: 'alarm', defaultValue: const TimeOfDay(hour: 7, minute: 0)),
  );

  // Text

  late final StringSetting nickname = _settings.own(
    StringSetting(
      storage: storage,
      key: 'nickname',
      defaultValue: 'guest',
      validator: SettingValidator.pattern(RegExp(r'^\w{1,10}$'), debugDescription: '1 to 10 letters or digits'),
    ),
  );

  late final StringNullableSetting signature = _settings.own(
    StringNullableSetting(
      storage: storage,
      key: 'signature',
      validator: SettingValidator.noneOf({'admin'}),
    ),
  );

  // Collections

  late final StringListSetting tags = _settings.own(
    StringListSetting(
      storage: storage,
      key: 'tags',
      defaultValue: const ['work', 'home'],
      validator: _reject((value) => value.contains('spam'), 'no spam tag'),
    ),
  );

  late final IntListSetting luckyNumbers = _settings.own(
    IntListSetting(
      storage: storage,
      key: 'lucky_numbers',
      defaultValue: const [7, 21],
      validator: _reject((value) => value.contains(13), 'no 13'),
    ),
  );

  late final MapSetting metadata = _settings.own(
    MapSetting(
      storage: storage,
      key: 'metadata',
      defaultValue: const <String, Object?>{},
      validator: _reject((value) => value.containsKey('password'), 'no password key'),
    ),
  );

  late final MapNullableSetting profile = _settings.own(
    MapNullableSetting(storage: storage, key: 'profile', defaultValue: const <String, Object?>{'name': 'Ada'}),
  );

  late final JsonSchemaMapSetting todoList = _settings.own(
    JsonSchemaMapSetting(
      storage: storage,
      key: 'todo_list',
      schema: todoListSchema,
      defaultValue: const <String, Object?>{'name': 'Inbox', 'todos': <Object?>[]},
    ),
  );

  late final JsonSchemaMapNullableSetting archivedTodoList = _settings.own(
    JsonSchemaMapNullableSetting(storage: storage, key: 'archived_todo_list', schema: todoListSchema),
  );

  // Counter

  late final IntSetting launchCount = _settings.own(
    IntSetting(storage: storage, key: 'launch_count', defaultValue: 0, validator: SettingValidator.range(min: 0)),
  );
}

/// Compares the ARGB value: a color read back from storage is a plain
/// `Color`, which is never equal to the `MaterialColor` `Colors.red`.
SettingValidator<C> _notRed<C extends Color?>() =>
    _reject((value) => value?.toARGB32() == Colors.red.toARGB32(), 'red is not allowed');

SettingValidator<T> _reject<T>(bool Function(T value) rejects, String debugDescription) => SettingValidator(
  (value) => rejects(value) ? ForbiddenValueValidationError(value, debugDescription: debugDescription) : null,
);
