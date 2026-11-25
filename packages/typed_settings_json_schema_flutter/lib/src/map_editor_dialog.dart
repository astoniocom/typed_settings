import 'dart:async';

import 'package:json_schema_builder/json_schema_builder.dart' as jsb;
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:material_ui/material_ui.dart';
import 'package:typed_settings_flutter/typed_settings_flutter_extend.dart';

/// Dialog for editing a `Map<String, Object?>` constrained by a JSON Schema.
///
/// Hosts `json_schema_form_builder` the same way its demo application does:
/// the value can be edited both through the generated form (Editor tab) and
/// as raw JSON text (Raw JSON tab, the package's own [JsonEditor] with
/// syntax highlighting). Both tabs edit the same value; changes made in one
/// are reflected in the other.
///
/// Pops a [DialogResult] of the edited map on OK, a [DialogResult] of null
/// when the clear button is used, and null on cancel. OK stays disabled
/// while the value fails the schema or the raw text is not a JSON object.
class MapEditorDialog extends StatefulWidget {
  /// Creates a dialog titled [label] that opens on [initial].
  const MapEditorDialog({
    required this.label,
    required this.initial,
    this.allowClear = false,
    this.schema,
    this.registry,
    super.key,
  });

  /// The title of the dialog.
  final String label;

  /// The map the dialog opens on.
  final Map<String, Object?> initial;

  /// When true, the dialog shows a button that closes it with a null map.
  final bool allowClear;

  /// The schema that drives the form and gates OK. A schema-free form when
  /// null: the form still edits the object, and OK requires a JSON object.
  final jsb.ObjectSchema? schema;

  /// Handler registry used to build and render the form.
  /// Defaults to [standardJsonHandlerRegistry].
  final JsonHandlerRegistry? registry;

  @override
  State<MapEditorDialog> createState() => _MapEditorDialogState();
}

class _MapEditorDialogState extends State<MapEditorDialog> with SingleTickerProviderStateMixin {
  late final JsonHandlerRegistry _registry = widget.registry ?? standardJsonHandlerRegistry();

  /// Form state rebuilds are asynchronous; fast edits can finish out of
  /// order, so only the latest rebuild is allowed to apply (demo pattern).
  late final LatestRequestGuard _rebuildGuard = LatestRequestGuard(isAlive: () => mounted);

  late final TabController _tabController;

  JsonFieldState? _formState;
  List<jsb.ValidationError>? _validationErrors;

  /// Why the latest rebuild failed. The spinner stops and the failure is
  /// shown; OK stays disabled.
  Object? _buildFailure;

  /// Parse error reported by the raw JSON editor; blocks submission while
  /// the text is not representable as a value.
  String? _rawParseError;

  bool _building = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    unawaited(_rebuild(PresenceValue<dynamic>(widget.initial)));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Rebuilds the form state for [value], validating it against the schema.
  ///
  /// A failure is reported and shown. It does not escape the future: the
  /// callers do not await it, and an escaped error would leave the spinner
  /// up.
  Future<void> _rebuild(PresenceValue<dynamic> value) {
    final schema = widget.schema;
    return _rebuildGuard.run(
      () async {
        try {
          final errors = await validateDataBySchema(schema, value.valueOrNull);
          final state = await _registry.withValidationContext(
            itemSchema: schema,
            rootSchema: null,
            body: (validationContext) => _registry.buildState(
              FieldBuildRequest(
                value: value,
                schemaSource: SchemaWithContext.maybe(schema, validationContext),
                title: schema?.title,
                errors: errors,
                resolveContext: FieldResolveContext(path: const [], rootSchema: schema),
              ),
            ),
          );
          return (state: state?.applyErrors(errors ?? []), errors: errors, failure: null);
          // Reported and returned. An escaped error would leave the spinner up.
          // ignore: avoid_catches_without_on_clauses
        } catch (error, stackTrace) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'typed_settings_json_schema_flutter',
              context: ErrorDescription('while building the map editor'),
            ),
          );
          return (state: null, errors: null, failure: error);
        }
      },
      (result) {
        if (!mounted) return;
        setState(() {
          _formState = result.state;
          _validationErrors = result.errors;
          _buildFailure = result.failure;
          _building = false;
        });
      },
    );
  }

  void _onFieldChanged(JsonFieldState newState) {
    unawaited(_rebuild(newState.value));
  }

  /// Raw tab edits: while the text does not parse, keep the last valid form
  /// state and only remember the error (it gates the OK button).
  void _onRawEdited(PresenceValue<dynamic> value, String? parseError) {
    setState(() => _rawParseError = parseError);
    if (parseError != null) return;
    unawaited(_rebuild(value));
  }

  bool get _canSubmit =>
      !_building && _rawParseError == null && (_validationErrors?.isEmpty ?? true) && _result() != null;

  /// The edited map, or null when the current form value is not an object.
  Map<String, Object?>? _result() {
    final state = _formState;
    if (state == null) return null;
    if (!state.hasValue) return const {};
    final value = state.valueOrNull;
    if (value is Map<String, Object?>) return value;
    if (value is Map) {
      final map = <String, Object?>{};
      for (final entry in value.entries) {
        final key = entry.key;
        if (key is! String) return null;
        map[key] = entry.value;
      }
      return map;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final messages = TypedSettingsLocalizations.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(widget.label)),
          CloseButton(onPressed: () => Navigator.pop(context)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(icon: const Icon(Icons.list), text: messages.editorTab),
                Tab(icon: const Icon(Icons.code), text: messages.rawJsonTab),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) => _tabController.index == 0 ? _buildFormTab(context) : _buildRawTab(context),
              ),
            ),
          ],
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
          onPressed: _canSubmit ? () => Navigator.pop(context, DialogResult<Map<String, Object?>?>(_result())) : null,
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }

  Widget _buildFormTab(BuildContext context) {
    if (_building) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final formState = _formState;
    if (formState == null) {
      final failure = _buildFailure;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              TypedSettingsLocalizations.of(context).unableToBuildEditor,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (failure != null) ...[
              const SizedBox(height: 8),
              Text('$failure', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: _registry
          .handlerForField(formState)
          .buildField(
            context: context,
            fieldState: formState,
            displayContext: FieldDisplayContext.root(formState: formState),
            onChanged: _onFieldChanged,
          ),
    );
  }

  Widget _buildRawTab(BuildContext context) {
    final errorText = _rawParseError == null && !_building && _result() == null
        ? TypedSettingsLocalizations.of(context).jsonMustBeObject
        : _formState?.errorsAsString;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: JsonEditor(
        expands: true,
        value: _formState?.value ?? PresenceValue<dynamic>(widget.initial),
        errorText: errorText,
        onChanged: _onRawEdited,
      ),
    );
  }
}
