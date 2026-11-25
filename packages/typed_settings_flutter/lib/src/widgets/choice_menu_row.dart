import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';
import 'package:typed_settings_flutter/src/widgets/settings_tile.dart';
import 'package:typed_settings_flutter/src/widgets/value_chip.dart';

/// A settings row that shows [value] and picks one of [options] from a
/// menu that a tap on the row opens.
///
/// Stateful so that an open menu survives a rebuild of the parent.
class ChoiceMenuRow<T> extends StatefulWidget {
  /// Creates a row titled [label] that offers [options].
  const ChoiceMenuRow({
    required this.value,
    required this.options,
    required this.nameOf,
    required this.onSelected,
    required this.label,
    this.subtitle,
    this.icon,
    super.key,
  });

  /// The option the row shows and the menu marks.
  final T value;

  /// The options of the menu, in order.
  final List<T> options;

  /// The name of an option in the menu and on the row.
  final String Function(T option) nameOf;

  /// Called with the option picked from the menu.
  final ValueChanged<T> onSelected;

  /// The title of the row.
  final String label;

  /// The text under the title.
  final String? subtitle;

  /// The widget before the title.
  final Widget? icon;

  @override
  State<ChoiceMenuRow<T>> createState() => _ChoiceMenuRowState<T>();
}

class _ChoiceMenuRowState<T> extends State<ChoiceMenuRow<T>> {
  final _popupKey = GlobalKey<PopupMenuButtonState<DialogResult<T>>>();

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      label: widget.label,
      subtitle: widget.subtitle,
      icon: widget.icon,
      onTap: () => _popupKey.currentState?.showButtonMenu(),
      trailing: PopupMenuButton<DialogResult<T>>(
        key: _popupKey,
        enabled: false,
        initialValue: DialogResult(widget.value),
        itemBuilder: (context) => [
          for (final option in widget.options)
            PopupMenuItem(
              value: DialogResult(option),
              child: Text(widget.nameOf(option)),
            ),
        ],
        onSelected: (result) => widget.onSelected(result.value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: ValueChip(value: widget.nameOf(widget.value))),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
