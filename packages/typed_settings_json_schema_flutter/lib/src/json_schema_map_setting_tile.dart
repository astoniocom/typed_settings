import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/typed_settings_flutter_extend.dart';
import 'package:typed_settings_json_schema/typed_settings_json_schema.dart';
import 'package:typed_settings_json_schema_flutter/src/json_schema_map_row.dart';

/// A tile that edits a [JsonSchemaMapSetting].
///
/// The editor form is driven by the setting's schema. A value the setting
/// rejects goes to the `SettingsErrorHandler` of the
/// `SettingsErrorHandlerProvider` above the tile.
class JsonSchemaMapSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const JsonSchemaMapSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The setting the tile shows and edits.
  final JsonSchemaMapSetting setting;

  /// The title of the tile and the editor; error messages name the setting
  /// by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final view = setting.editorView(context, label: label);
    return ValueListenableBuilder(
      valueListenable: view,
      builder: (context, value, _) {
        return JsonSchemaMapRow(
          value: value,
          label: label,
          subtitle: subtitle,
          icon: icon,
          schema: setting.schema,
          onSubmit: (result) => view.value = result,
        );
      },
    );
  }
}
