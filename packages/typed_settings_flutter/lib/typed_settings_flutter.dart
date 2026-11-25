/// Flutter tools for `typed_settings`: bindings and tiles for quickly
/// prototyping settings screens, including a screen that ships in a
/// release build.
///
/// Re-exports `package:typed_settings/typed_settings.dart`, so a Flutter
/// application imports this library alone (plus the library of the storage
/// it uses: `package:typed_settings/typed_settings_in_memory.dart`,
/// `typed_settings_dao.dart` or a backend package), and adds what needs
/// Flutter:
///
/// * `setting.editorView(context, label:)`: a `ValueNotifier` view of a
///   setting whose rejected values go to the `SettingsErrorHandler` above
///   the context. Reading needs no view: a setting is a `ValueListenable`,
///   so `ValueListenableBuilder` and `Listenable.merge` take it directly.
/// * `ColorSetting`, `ColorNullableSetting`, `ColorArgbCodec`: a `Color`
///   stored as its ARGB value.
/// * `LocaleSetting`, `LocaleNullableSetting`, `LocaleSubtagsCodec`,
///   `LocaleValidator`: a `Locale` stored as its language, script and
///   region. A variant or an extension is rejected. `LocaleValidator`
///   keeps only the locales the application lists, compared in full:
///   `Locale('ru')` does not accept `Locale('ru', 'RU')`. `AppliedLocale`
///   reads a `ValueListenable<Locale?>` (`null` means "follow the device")
///   and gives the locale for `MaterialApp`, including a later change of
///   the device language.
/// * `TimeOfDaySetting`, `TimeOfDayNullableSetting`,
///   `TimeOfDayMinutesCodec`: a `TimeOfDay` stored as the minutes since
///   midnight. `TimeOfDayRangeSetting` and
///   `TimeOfDayRangeNullableSetting` store a pair of them as one value.
///   The end may be earlier than the start: that range crosses midnight.
/// * `FlutterErrorSettingsObserver`: reports through `FlutterError`, so
///   events reach the crash reporter in release builds. Pass it to each
///   storage; a storage without an observer prints to the console.
/// * Material setting tiles (`IntSettingTile`, `EnumSettingTile`,
///   `LocaleSettingTile`, `TimeOfDaySettingTile`, `MapSettingTile`, ...)
///   that show a setting and edit it in a dialog or menu, and the same
///   controls without the `Setting` suffix (`IntTile`, `EnumTile`, ...)
///   that edit the `ValueNotifier` given as `notifier`.
///   `SettingsErrorHandler` with `SettingsErrorHandlerProvider` decide how
///   a setting tile reports a rejected value. A map is edited as JSON. A
///   map checked against a JSON Schema is edited with
///   `typed_settings_json_schema_flutter`. What a tile of a new kind is
///   built from is in `typed_settings_flutter_extend.dart`.
/// * `TypedSettingsLocalizations`: editor text that the framework
///   localizations do not have. English unless a subclass is installed with
///   a `Localizations` delegate. OK, Cancel, the hour and minute labels,
///   and the delete tooltip come from Material. Clearing a value or a
///   color does not: Material's clear tooltip talks about text. The
///   move-up and move-down tooltips come from the widgets localizations.
library;

export 'package:typed_settings/typed_settings.dart';

export 'src/codec/color_argb_codec.dart';
export 'src/codec/locale_subtags_codec.dart';
export 'src/codec/time_of_day_minutes_codec.dart';
export 'src/error_handling/setting_editor_view.dart';
export 'src/error_handling/settings_error_handler.dart';
export 'src/error_handling/settings_error_handler_provider.dart';
export 'src/error_handling/snackbar_settings_error_handler.dart';
export 'src/flutter_error_settings_observer.dart';
export 'src/locale/applied_locale.dart';
export 'src/presets/color_setting.dart';
export 'src/presets/locale_setting.dart';
export 'src/presets/time_of_day_setting.dart';
export 'src/tiles/bool_checkbox_setting_tile.dart';
export 'src/tiles/bool_nullable_dropdown_setting_tile.dart';
export 'src/tiles/bool_nullable_setting_tile.dart';
export 'src/tiles/bool_switch_setting_tile.dart';
export 'src/tiles/color_nullable_setting_tile.dart';
export 'src/tiles/color_setting_tile.dart';
export 'src/tiles/date_time_nullable_setting_tile.dart';
export 'src/tiles/date_time_setting_tile.dart';
export 'src/tiles/double_nullable_setting_tile.dart';
export 'src/tiles/double_setting_tile.dart';
export 'src/tiles/duration_nullable_setting_tile.dart';
export 'src/tiles/duration_setting_tile.dart';
export 'src/tiles/enum_nullable_setting_tile.dart';
export 'src/tiles/enum_setting_tile.dart';
export 'src/tiles/int_list_setting_tile.dart';
export 'src/tiles/int_nullable_setting_tile.dart';
export 'src/tiles/int_setting_tile.dart';
export 'src/tiles/locale_nullable_setting_tile.dart';
export 'src/tiles/locale_setting_tile.dart';
export 'src/tiles/map_nullable_setting_tile.dart';
export 'src/tiles/map_setting_tile.dart';
export 'src/tiles/string_list_setting_tile.dart';
export 'src/tiles/string_nullable_setting_tile.dart';
export 'src/tiles/string_setting_tile.dart';
export 'src/tiles/theme_setting_tile.dart';
export 'src/tiles/time_of_day_nullable_setting_tile.dart';
export 'src/tiles/time_of_day_setting_tile.dart';
export 'src/typed_settings_localizations.dart';
export 'src/validation/locale_validator.dart';
