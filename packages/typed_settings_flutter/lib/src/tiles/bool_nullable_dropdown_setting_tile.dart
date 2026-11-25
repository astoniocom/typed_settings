import 'package:material_ui/material_ui.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings_flutter/src/error_handling/setting_editor_view.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';
import 'package:typed_settings_flutter/src/widgets/value_chip.dart';

/// A tile that edits a `bool?` setting with a menu of `true`, `false` and
/// `null`.
///
/// The menu disables the states the setting rejects.
class BoolNullableDropdownSettingTile extends StatelessWidget {
  /// Creates a tile that edits [setting].
  const BoolNullableDropdownSettingTile({
    required this.setting,
    required this.label,
    this.subtitle,
    this.icon,
    this.trueLabel,
    this.falseLabel,
    this.nullLabel,
    this.trueIcon,
    this.falseIcon,
    this.nullIcon,
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

  /// The name of `true` in the menu and on the tile.
  /// [TypedSettingsLocalizations.enabledLabel] when null.
  final String? trueLabel;

  /// The name of `false` in the menu and on the tile.
  /// [TypedSettingsLocalizations.disabledLabel] when null.
  final String? falseLabel;

  /// The name of `null` in the menu and on the tile. `null` is a stored
  /// value of its own, not the setting's default.
  /// [TypedSettingsLocalizations.notSetLabel] when null.
  final String? nullLabel;

  /// The icon next to [trueLabel].
  final IconData? trueIcon;

  /// The icon next to [falseLabel].
  final IconData? falseIcon;

  /// The icon next to [nullLabel].
  final IconData? nullIcon;

  @override
  Widget build(BuildContext context) {
    return BoolNullableDropdownTile(
      notifier: setting.editorView(context, label: label),
      validator: setting.validate,
      label: label,
      subtitle: subtitle,
      icon: icon,
      trueLabel: trueLabel,
      falseLabel: falseLabel,
      nullLabel: nullLabel,
      trueIcon: trueIcon,
      falseIcon: falseIcon,
      nullIcon: nullIcon,
    );
  }
}

/// Shows and edits [notifier] the way [BoolNullableDropdownSettingTile] edits a setting.
///
/// [BoolNullableDropdownSettingTile] binds this tile to a `Setting` and reports a
/// rejected value. This tile stores whatever [notifier] accepts.
class BoolNullableDropdownTile extends StatefulWidget {
  /// Creates a tile that edits [notifier].
  const BoolNullableDropdownTile({
    required this.notifier,
    required this.label,
    this.trueLabel,
    this.falseLabel,
    this.nullLabel,
    this.validator,
    this.subtitle,
    this.icon,
    this.trueIcon,
    this.falseIcon,
    this.nullIcon,
    super.key,
  });

  /// The notifier the tile shows and edits.
  ///
  /// A plain [ValueNotifier] stores every assignment. A view from
  /// `Setting.editorView` reports a rejected value instead.
  final ValueNotifier<bool?> notifier;

  /// Rejects a candidate before it is stored. Accepts every value when omitted.
  final ValidationError? Function(bool? value)? validator;

  /// The title of the tile.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  /// See [BoolNullableDropdownSettingTile.trueLabel].
  final String? trueLabel;

  /// See [BoolNullableDropdownSettingTile.falseLabel].
  final String? falseLabel;

  /// See [BoolNullableDropdownSettingTile.nullLabel].
  final String? nullLabel;

  /// See [trueIcon] on the setting tile.
  final IconData? trueIcon;

  /// See [falseIcon] on the setting tile.
  final IconData? falseIcon;

  /// See [nullIcon] on the setting tile.
  final IconData? nullIcon;

  @override
  State<BoolNullableDropdownTile> createState() => _BoolNullableDropdownTileState();
}

class _BoolNullableDropdownTileState extends State<BoolNullableDropdownTile> {
  final _popupKey = GlobalKey<PopupMenuButtonState<DialogResult<bool?>?>>();

  String _stateLabel(bool? value) {
    final messages = TypedSettingsLocalizations.of(context);
    return switch (value) {
      true => widget.trueLabel ?? messages.enabledLabel,
      false => widget.falseLabel ?? messages.disabledLabel,
      null => widget.nullLabel ?? messages.notSetLabel,
    };
  }

  IconData? _stateIcon(bool? value) {
    return switch (value) {
      true => widget.trueIcon,
      false => widget.falseIcon,
      null => widget.nullIcon,
    };
  }

  void _onSelected(DialogResult<bool?>? newValue) {
    if (newValue == null) return;
    widget.notifier.value = newValue.value;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: widget.notifier,
      builder: (context, value, _) {
        final icon = _stateIcon(value);
        return SettingsTile(
          label: widget.label,
          subtitle: widget.subtitle,
          icon: widget.icon,
          trailing: PopupMenuButton<DialogResult<bool?>?>(
            key: _popupKey,
            onSelected: _onSelected,
            enabled: false,
            itemBuilder: (context) => [true, false, null]
                .map((value) {
                  final icon = _stateIcon(value);
                  return PopupMenuItem(
                    value: DialogResult(value),
                    enabled: widget.validator?.call(value) == null,
                    child: Row(
                      children: [
                        if (icon != null) ...[
                          Icon(icon),
                          const SizedBox(width: 8),
                        ],
                        Text(_stateLabel(value)),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon),
                  const SizedBox(width: 8),
                ],
                Flexible(child: ValueChip(value: _stateLabel(value))),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          onTap: () => _popupKey.currentState?.showButtonMenu(),
        );
      },
    );
  }
}
