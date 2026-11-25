import 'package:material_ui/material_ui.dart';

/// A dialog that edits a text.
///
/// Pops with the text on OK and with `null` when dismissed. OK is disabled
/// while [validator] reports an error.
class StringEditDialog extends StatefulWidget {
  /// Creates a dialog titled [title] that opens on [initial].
  const StringEditDialog({
    required this.title,
    this.validator,
    this.initial = '',
    super.key,
  });

  /// The title of the dialog.
  final String title;

  /// The text the dialog opens on.
  final String initial;

  /// The error message for a text, or null when the text is valid.
  final String? Function(String text)? validator;

  @override
  State<StringEditDialog> createState() => _StringEditDialogState();
}

class _StringEditDialogState extends State<StringEditDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final error = widget.validator?.call(_controller.text);
        return AlertDialog(
          title: Text(widget.title),
          content: TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(errorText: error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancelButtonLabel),
            ),
            TextButton(
              onPressed: error == null ? () => Navigator.pop(context, _controller.text) : null,
              child: Text(localizations.okButtonLabel),
            ),
          ],
        );
      },
    );
  }
}
