import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/map_row.dart';

/// A tile that shows the size of a `Map<String, Object?>?` setting and edits
/// the map as JSON.
///
/// While the setting holds a value, the editor dialog shows a button that
/// clears it to `null`.
///
/// The editor checks that the text is a JSON object and does not apply a
/// schema. Submitting an empty map stores `null`, so the tile cannot store
/// an empty map. While that stored value is one the setting rejects, OK
/// stays disabled and the dialog shows
/// [TypedSettingsLocalizations.validationMessage]. The text stays in the field.
class MapNullableSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const MapNullableSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<Map<String, Object?>?> setting;

  /// The title of the tile and the editor; error messages name the setting
  /// by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return MapNullableTile(
      notifier: setting.editorView(context, label: label),
      label: label,
      validator: setting.validate,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

/// Shows and edits [notifier] the way [MapNullableSettingTile] edits a
/// setting.
///
/// [MapNullableSettingTile] binds this tile to a `Setting`. This tile
/// stores whatever [notifier] accepts. [validator] keeps a rejected object
/// in the dialog.
class MapNullableTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const MapNullableTile({
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
  final ValueNotifier<Map<String, Object?>?> notifier;

  /// The title of the tile and the editor.
  final String label;

  /// Rejects a candidate before it is stored; an empty object is checked
  /// as `null`, the value it stores. The dialog shows
  /// [TypedSettingsLocalizations.validationMessage] for the error and keeps
  /// the text. Accepts every value when omitted.
  final ValidationError? Function(Map<String, Object?>? value)? validator;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  static Map<String, Object?>? _stored(Map<String, Object?> map) => map.isEmpty ? null : map;

  @override
  Widget build(BuildContext context) {
    final check = validator;
    return ValueListenableBuilder(
      valueListenable: notifier,
      builder: (context, value, _) {
        return MapRow(
          value: value,
          label: label,
          subtitle: subtitle,
          icon: icon,
          onClear: value == null ? null : () => notifier.value = null,
          validator: check == null ? null : (map) => check(_stored(map)),
          onSubmit: (result) => notifier.value = _stored(result),
        );
      },
    );
  }
}
