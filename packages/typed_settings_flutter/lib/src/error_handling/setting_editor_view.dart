import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler.dart';
import 'package:typed_settings_flutter/src/error_handling/settings_error_handler_provider.dart';

/// Hands a [Setting] to the tiles that edit a plain [ValueNotifier].
extension SettingEditorView<T> on Setting<T> {
  /// A [ValueNotifier] view of this setting whose rejected values go to the
  /// [SettingsErrorHandler] of [context], reported under [label].
  ///
  /// Two views are equal when they wrap the same setting in the same
  /// [context] under the same [label]. A tile that builds a fresh view on
  /// every rebuild therefore does not resubscribe. The handler is read when
  /// a value is rejected, without subscribing [context] to the provider, so
  /// the provider above [context] at that moment is the one that reports.
  /// Once [context] is unmounted the rejection is reported through
  /// [FlutterError] instead: the handler would have no tree to show it in.
  ValueNotifier<T> editorView(BuildContext context, {required String label}) =>
      _EditorSettingNotifier<T>(this, context, label);
}

/// The `editorView` of one setting, context and label.
///
/// Equality is the setting, the context and the label. The listener list
/// is not part of it, so a rebuilt tile can keep the view it already
/// subscribed.
@immutable
class _EditorSettingNotifier<T> implements ValueNotifier<T> {
  /// Creates the view of the setting, reported under the label from the context.
  _EditorSettingNotifier(this._setting, this._context, this._label);

  final Setting<T> _setting;
  final BuildContext _context;
  final String _label;
  final SettingViewListeners _listeners = SettingViewListeners();

  @override
  T get value => _setting.value;

  @override
  set value(T newValue) {
    _listeners.checkUsable('value=');
    try {
      _setting.value = newValue;
    } on SettingValidationException catch (exception) {
      if (!_context.mounted) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: exception,
            library: 'typed_settings_flutter',
            context: ErrorDescription(
              'while reporting that $_label rejected a value after its editor was unmounted',
            ),
          ),
        );
        return;
      }
      SettingsErrorHandlerProvider.of(_context).handleValidationError(_context, _label, exception);
    }
  }

  @override
  void addListener(VoidCallback listener) => _listeners.add(_setting, listener);

  @override
  void removeListener(VoidCallback listener) => _listeners.remove(_setting, listener);

  @override
  void dispose() => _listeners.dispose(_setting);

  @override
  void notifyListeners() => _listeners.notify();

  @override
  bool get hasListeners => _listeners.hasListeners;

  @override
  bool operator ==(Object other) =>
      other is _EditorSettingNotifier<T> &&
      identical(other._setting, _setting) &&
      identical(other._context, _context) &&
      other._label == _label;

  @override
  int get hashCode => Object.hash(identityHashCode(_setting), identityHashCode(_context), _label);

  @override
  String toString() => '${describeIdentity(this)}($_setting)';
}
