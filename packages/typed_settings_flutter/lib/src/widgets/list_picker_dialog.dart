import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';

/// A dialog that edits a list: adds parsed items, removes and reorders
/// them.
///
/// Pops with the edited list on OK and with `null` when dismissed.
class ListPickerDialog<T> extends StatefulWidget {
  /// Creates a dialog titled [title] that opens on [initial].
  const ListPickerDialog({
    required this.title,
    required this.initial,
    required this.parse,
    this.validate,
    this.validateList,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    super.key,
  });

  /// Turns the entered text into an item; an item is not added while it
  /// throws an [Exception].
  final T Function(String text) parse;

  /// The error message for an entered text, or null when it is valid.
  final String? Function(String text)? validate;

  /// The error message for the whole list, or null when the list is acceptable.
  ///
  /// OK stays disabled while this returns a message. The items stay in the dialog.
  final String? Function(List<T> items)? validateList;

  /// The title of the dialog.
  final String title;

  /// The items the dialog opens on.
  final List<T> initial;

  /// The keyboard of the field for a new item.
  final TextInputType keyboardType;

  /// The formatters of the field for a new item.
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<ListPickerDialog<T>> createState() => _ListPickerDialogState<T>();
}

/// One item of the list, so its row keeps its key while it moves and two
/// equal items are still two rows.
final class _Entry<T> {
  _Entry(this.value);

  final T value;
}

class _ListPickerDialogState<T> extends State<ListPickerDialog<T>> {
  late final List<_Entry<T>> _items;
  late final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = [for (final value in widget.initial) _Entry(value)];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  T? get _parsed {
    try {
      return widget.parse(_controller.text.trim());
    } on Exception {
      return null;
    }
  }

  void _validate(String text) {
    setState(() {
      if (text.trim().isEmpty) {
        _error = null;
        return;
      }
      _error = widget.validate?.call(text);
    });
  }

  void _add() {
    final value = _parsed;
    if (value == null || _error != null) return;
    setState(() {
      _items.add(_Entry(value));
      _controller.clear();
      _error = null;
    });
  }

  void _remove(int index) {
    setState(() => _items.removeAt(index));
  }

  void _moveUp(int index) {
    if (index == 0) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(index - 1, item);
    });
  }

  void _moveDown(int index) {
    if (index == _items.length - 1) return;
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(index + 1, item);
    });
  }

  bool get _canAdd => _error == null && _controller.text.trim().isNotEmpty && _parsed != null;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final messages = TypedSettingsLocalizations.of(context);
    final items = List<T>.unmodifiable(_items.map((entry) => entry.value));
    final listError = widget.validateList?.call(items);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.title)),
          CloseButton(onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: messages.newListValue,
                errorText: _error,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _canAdd ? _add : null,
                ),
              ),
              onChanged: _validate,
              onSubmitted: (_) => _add(),
            ),
            const SizedBox(height: 16),
            if (_items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    messages.noListItems,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  itemCount: _items.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() => _items.insert(newIndex, _items.removeAt(oldIndex)));
                  },
                  itemBuilder: (context, index) {
                    final entry = _items[index];
                    return ReorderableDelayedDragStartListener(
                      key: ObjectKey(entry),
                      index: index,
                      child: ListTile(
                        dense: true,
                        title: Text(
                          '${entry.value}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontFamily: 'monospace',
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_upward, size: 18),
                              tooltip: WidgetsLocalizations.of(context).reorderItemUp,
                              onPressed: index > 0 ? () => _moveUp(index) : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_downward, size: 18),
                              tooltip: WidgetsLocalizations.of(context).reorderItemDown,
                              onPressed: index < _items.length - 1 ? () => _moveDown(index) : null,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: localizations.deleteButtonTooltip,
                              color: Theme.of(context).colorScheme.error,
                              onPressed: () => _remove(index),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (listError != null) ...[
              const SizedBox(height: 12),
              Text(listError, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
      actions: [
        // Item count
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            messages.listItemCount(items.length),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ),

        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: listError == null ? () => Navigator.pop(context, items) : null,
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }
}
