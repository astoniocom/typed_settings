import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/typed_settings_flutter_extend.dart';
import 'package:typed_settings_json_schema_flutter/src/map_editor_dialog.dart';

/// The presentation shared by the schema map setting tiles.
///
/// Holds no setting itself: the current [value] and the reactions
/// ([onSubmit], [onClear]) are supplied by the public tiles.
class JsonSchemaMapRow extends StatelessWidget {
  /// Creates a row that shows [value] and edits it in a [MapEditorDialog].
  const JsonSchemaMapRow({
    required this.value,
    required this.label,
    required this.onSubmit,
    this.onClear,
    this.subtitle,
    this.icon,
    this.schema,
    super.key,
  });

  /// The map the tile shows and the editor opens on; an empty map when
  /// null.
  final Map<String, Object?>? value;

  /// The title of the tile and the editor.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// The schema that drives the editor's form.
  final Schema? schema;

  /// Called with the map confirmed in the editor dialog.
  final ValueChanged<Map<String, Object?>> onSubmit;

  /// When non-null, the editor dialog shows a button that clears the value
  /// by invoking this callback.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final count = value?.length ?? 0;
    return SettingsTile(
      label: label,
      subtitle: subtitle,
      icon: icon,
      trailing: CountBadge(count: count),
      onTap: () => _showDialog(context),
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final result = await showDialog<DialogResult<Map<String, Object?>?>>(
      context: context,
      builder: (context) => MapEditorDialog(
        label: label,
        initial: value ?? const {},
        allowClear: onClear != null,
        schema: schema as ObjectSchema?,
      ),
    );
    if (result == null || !context.mounted) return;
    final map = result.value;
    if (map == null) {
      onClear?.call();
      return;
    }
    onSubmit(map);
  }
}
