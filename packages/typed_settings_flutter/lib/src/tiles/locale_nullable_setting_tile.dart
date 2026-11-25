import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/tiles/locale_setting_tile.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/choice_menu_row.dart';

/// A tile that shows a `Locale?` setting and picks `null` or one of
/// [locales] from a menu. `null` is the usual "follow the device" choice.
///
/// A value the setting rejects goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile.
class LocaleNullableSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const LocaleNullableSettingTile({
    required this.setting,
    required this.label,
    required this.locales,
    this.nullLabel,
    this.subtitle,
    this.icon,
    this.nameBuilder,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<Locale?> setting;

  /// The title of the tile; error messages name the setting by it.
  final String label;

  /// See [LocaleSettingTile.locales].
  final List<Locale> locales;

  /// The name of `null` in the menu and on the tile, such as "System
  /// language". [TypedSettingsLocalizations.notSetLabel] when null.
  final String? nullLabel;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// See [LocaleSettingTile.nameBuilder].
  final String Function(Locale locale)? nameBuilder;

  @override
  Widget build(BuildContext context) {
    return LocaleNullableTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      locales: locales,
      nullLabel: nullLabel,
      subtitle: subtitle,
      icon: icon,
      nameBuilder: nameBuilder,
    );
  }
}

/// Shows and edits [notifier] the way [LocaleNullableSettingTile] edits a
/// setting.
///
/// [LocaleNullableSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class LocaleNullableTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const LocaleNullableTile({
    required this.notifier,
    required this.label,
    required this.locales,
    this.nullLabel,
    this.subtitle,
    this.icon,
    this.nameBuilder,
    super.key,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<Locale?> notifier;

  /// The title of the tile.
  final String label;

  /// See [LocaleSettingTile.locales].
  final List<Locale> locales;

  /// See [LocaleNullableSettingTile.nullLabel].
  final String? nullLabel;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// See [LocaleSettingTile.nameBuilder].
  final String Function(Locale locale)? nameBuilder;

  @override
  Widget build(BuildContext context) {
    final nullName = nullLabel ?? TypedSettingsLocalizations.of(context).notSetLabel;
    final name = nameBuilder ?? (locale) => locale.toLanguageTag();
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) => ChoiceMenuRow<Locale?>(
        value: value,
        options: [null, ...locales],
        nameOf: (locale) => locale == null ? nullName : name(locale),
        onSelected: (locale) => notifier.value = locale,
        label: label,
        subtitle: subtitle,
        icon: icon,
      ),
    );
  }
}
