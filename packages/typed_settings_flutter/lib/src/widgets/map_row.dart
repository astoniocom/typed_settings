import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/count_badge.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';
import 'package:typed_settings_flutter/src/widgets/map_editor_dialog.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';

/// The row shared by the map tiles.
///
/// Holds no notifier itself: the current [value] and the reactions
/// ([onSubmit], [onClear], [validator]) are supplied by the public tiles.
/// The editor accepts a JSON object that [validator] accepts. A schema
/// belongs to `typed_settings_json_schema_flutter`.
class MapRow extends StatelessWidget {
  /// Creates a row that shows [value] and edits it in a [MapEditorDialog].
  const MapRow({
    required this.value,
    required this.label,
    required this.onSubmit,
    this.onClear,
    this.validator,
    this.subtitle,
    this.icon,
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

  /// Called with the map confirmed in the editor dialog.
  final ValueChanged<Map<String, Object?>> onSubmit;

  /// When non-null, the editor dialog shows a button that clears the value
  /// by invoking this callback.
  final VoidCallback? onClear;

  /// Rejects a parsed object before [onSubmit]. The dialog shows
  /// [TypedSettingsLocalizations.validationMessage] for the error and keeps
  /// the text. Accepts every object when omitted.
  final ValidationError? Function(Map<String, Object?> value)? validator;

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      label: label,
      subtitle: subtitle,
      icon: icon,
      trailing: CountBadge(count: value?.length ?? 0),
      onTap: () => _showDialog(context),
    );
  }

  Future<void> _showDialog(BuildContext context) async {
    final result = await showDialog<DialogResult<Map<String, Object?>?>>(
      context: context,
      builder: (context) {
        final check = validator;
        final messages = TypedSettingsLocalizations.of(context);
        return MapEditorDialog(
          label: label,
          initial: value ?? const {},
          allowClear: onClear != null,
          validate: check == null
              ? null
              : (map) {
                  final error = check(map);
                  return error == null ? null : messages.validationMessage(error);
                },
        );
      },
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
