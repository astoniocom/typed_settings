import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/widgets/choice_menu_row.dart';

/// A tile that shows a [Locale] setting and picks one of [locales] from a
/// menu.
///
/// A value the setting rejects goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile.
class LocaleSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const LocaleSettingTile({
    required this.setting,
    required this.label,
    required this.locales,
    this.subtitle,
    this.icon,
    this.nameBuilder,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<Locale> setting;

  /// The title of the tile; error messages name the setting by it.
  final String label;

  /// The locales the menu offers, usually the application's
  /// `supportedLocales`.
  final List<Locale> locales;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// The name of a locale in the menu and on the tile; its
  /// [Locale.toLanguageTag] when null. Pass the language's own name
  /// (`Deutsch`, `English`) for a language picker.
  final String Function(Locale locale)? nameBuilder;

  @override
  Widget build(BuildContext context) {
    return LocaleTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      locales: locales,
      subtitle: subtitle,
      icon: icon,
      nameBuilder: nameBuilder,
    );
  }
}

/// Shows and edits [notifier] the way [LocaleSettingTile] edits a setting.
///
/// [LocaleSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class LocaleTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const LocaleTile({
    required this.notifier,
    required this.label,
    required this.locales,
    this.subtitle,
    this.icon,
    this.nameBuilder,
    super.key,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<Locale> notifier;

  /// The title of the tile.
  final String label;

  /// See [LocaleSettingTile.locales].
  final List<Locale> locales;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// See [LocaleSettingTile.nameBuilder].
  final String Function(Locale locale)? nameBuilder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) => ChoiceMenuRow<Locale>(
        value: value,
        options: locales,
        nameOf: nameBuilder ?? (locale) => locale.toLanguageTag(),
        onSelected: (locale) => notifier.value = locale,
        label: label,
        subtitle: subtitle,
        icon: icon,
      ),
    );
  }
}
