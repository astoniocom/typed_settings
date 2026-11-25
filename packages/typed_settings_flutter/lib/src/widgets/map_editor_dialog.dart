import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/src/typed_settings_localizations.dart';
import 'package:typed_settings_flutter/src/widgets/dialog_result.dart';

/// Dialog for editing a `Map<String, Object?>` as JSON text.
///
/// There is no schema and no validation beyond "this text is a JSON
/// object" and [validate]. OK stays disabled while the text does not parse,
/// parses as something other than an object, or [validate] rejects the
/// object. A parse failure uses [TypedSettingsLocalizations.invalidJson] and
/// names the character index the parser reported. A key that is not a string
/// is reported the same way. The text stays in the field.
///
/// Pops a [DialogResult] of the edited map on OK, a [DialogResult] of null
/// when the clear button is used, and null on cancel.
class MapEditorDialog extends StatefulWidget {
  /// Creates a dialog titled [label] that opens on [initial].
  const MapEditorDialog({
    required this.label,
    required this.initial,
    this.allowClear = false,
    this.validate,
    super.key,
  });

  /// The title of the dialog.
  final String label;

  /// The map the dialog opens on.
  final Map<String, Object?> initial;

  /// When true, the dialog shows a button that closes it with a null map.
  final bool allowClear;

  /// The message for a parsed object the caller rejects, or null when that
  /// object is acceptable. OK stays disabled while this returns a message.
  final String? Function(Map<String, Object?> value)? validate;

  @override
  State<MapEditorDialog> createState() => _MapEditorDialogState();
}

class _MapEditorDialogState extends State<MapEditorDialog> {
  late final TextEditingController _controller;

  /// Why the text cannot be stored.
  _MapTextError? _errorKind;

  /// Character index of [_MapTextError.invalid], when the parser reported one.
  int? _errorOffset;
  Map<String, Object?>? _parsed;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: const JsonEncoder.withIndent('  ').convert(widget.initial));
    _read(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() => _read(text));
  }

  /// Parses [text] into [_parsed], or records why it cannot be stored.
  void _read(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException catch (error) {
      _errorKind = _MapTextError.invalid;
      _errorOffset = error.offset;
      _parsed = null;
      return;
    }
    if (decoded is! Map) {
      _errorKind = _MapTextError.notObject;
      _errorOffset = null;
      _parsed = null;
      return;
    }
    final map = <String, Object?>{};
    for (final entry in decoded.entries) {
      final key = entry.key;
      if (key is! String) {
        _errorKind = _MapTextError.nonStringKey;
        _errorOffset = null;
        _parsed = null;
        return;
      }
      map[key] = entry.value;
    }
    _errorKind = null;
    _errorOffset = null;
    _parsed = map;
  }

  String? _message(TypedSettingsLocalizations messages) {
    final structural = switch (_errorKind) {
      _MapTextError.invalid => messages.invalidJson(_errorOffset),
      _MapTextError.notObject => messages.jsonMustBeObject,
      _MapTextError.nonStringKey => messages.jsonKeysMustBeStrings,
      null => null,
    };
    if (structural != null) return structural;
    final parsed = _parsed;
    if (parsed == null) return null;
    return widget.validate?.call(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final messages = TypedSettingsLocalizations.of(context);
    final parsed = _parsed;
    final message = _message(messages);
    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.label)),
          CloseButton(onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: TextField(
          controller: _controller,
          keyboardType: TextInputType.multiline,
          maxLines: 12,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            errorText: message,
            errorMaxLines: 4,
          ),
          onChanged: _onChanged,
        ),
      ),
      actions: [
        if (widget.allowClear)
          TextButton(
            onPressed: () => Navigator.pop(context, const DialogResult<Map<String, Object?>?>(null)),
            child: Text(messages.clearValueLabel),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: parsed != null && message == null
              ? () => Navigator.pop(context, DialogResult<Map<String, Object?>?>(parsed))
              : null,
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }
}

enum _MapTextError { invalid, notObject, nonStringKey }
