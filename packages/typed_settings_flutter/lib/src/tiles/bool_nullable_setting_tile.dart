import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';

/// A tile that edits a `bool?` setting with a tristate checkbox.
///
/// A tap moves to the next of `null`, `true` and `false` that the setting
/// accepts. A rejected state is skipped. When none of the others is
/// accepted, the rejection goes to the [SettingsErrorHandler] of the
/// [SettingsErrorHandlerProvider] above the tile and the value stays.
class BoolNullableCheckboxSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const BoolNullableCheckboxSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The setting the tile shows and edits.
  final Setting<bool?> setting;

  /// The title of the tile; error messages name the setting by it.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return BoolNullableCheckboxTile._ofSetting(
      notifier: setting.editorView(context, label: label),
      validator: setting.validate,
      diagnosticKey: setting.diagnosticKey,
      label: label,
      subtitle: subtitle,
      icon: icon,
    );
  }
}

/// Shows and edits [notifier] the way [BoolNullableCheckboxSettingTile] edits a setting.
///
/// A tap moves to the next of `null`, `true` and `false` that [validator]
/// accepts. A rejected state is skipped. When none of the others is
/// accepted, that rejection is reported and the value stays. When
/// [validator] is omitted, the tap stores the immediate next value, and a
/// view from `Setting.editorView` reports a rejection itself.
class BoolNullableCheckboxTile extends StatelessWidget {
  /// Creates a tile that edits [notifier].
  const BoolNullableCheckboxTile({
    required this.notifier,
    required this.label,
    this.validator,
    this.subtitle,
    this.icon,
    super.key,
  }) : _diagnosticKey = null;

  const BoolNullableCheckboxTile._ofSetting({
    required this.notifier,
    required this.label,
    required this.validator,
    required this._diagnosticKey,
    this.subtitle,
    this.icon,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<bool?> notifier;

  /// Rejects a candidate. The tile skips it and stores the next accepted
  /// value. When every other value is rejected, the first rejection is
  /// reported and nothing is stored. Accepts every value when omitted.
  final ValidationError? Function(bool? value)? validator;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// The diagnostic key of the setting a rejection this tile reports names.
  final String? _diagnosticKey;

  static const _cycle = [null, true, false];

  void _cycleValue(BuildContext context) {
    final currentIndex = _cycle.indexOf(notifier.value);
    final start = currentIndex < 0 ? 0 : currentIndex;
    ValidationError? firstRejection;
    for (var step = 1; step < _cycle.length; step++) {
      final next = _cycle[(start + step) % _cycle.length];
      final error = validator?.call(next);
      if (error == null) {
        notifier.value = next;
        return;
      }
      firstRejection ??= error;
    }
    if (firstRejection == null) return;
    SettingsErrorHandlerProvider.of(context).handleValidationError(
      context,
      label,
      SettingValidationException(_diagnosticKey, firstRejection),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: notifier,
      builder: (context, value, _) {
        return SettingsTile(
          label: label,
          subtitle: subtitle,
          icon: icon,
          trailing: Checkbox(
            value: value,
            tristate: true,
            onChanged: (_) => _cycleValue(context),
          ),
          onTap: () => _cycleValue(context),
        );
      },
    );
  }
}
