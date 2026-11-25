import 'package:typed_settings/typed_settings.dart';

/// Collects every event for assertions.
base class RecordingObserver extends SettingsObserver {
  /// Every event reported so far, in order.
  final List<SettingsEvent> events = [];

  /// The messages of [events], in order.
  List<String> get messages => [for (final event in events) event.message];

  @override
  void onEvent(SettingsEvent event) => events.add(event);
}
