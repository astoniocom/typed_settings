import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:typed_settings/typed_settings_backend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';
import 'package:typed_settings_flutter/typed_settings_flutter.dart';

final class _FailingBackend extends StringBackedStorage {
  _FailingBackend({super.observer}) : super(cache: {});

  @override
  Future<Map<String, String>> loadRaw() async => {};

  @override
  Future<void> writeRaw(String key, String value) async => throw StateError('disk full');

  @override
  Future<void> deleteRaw(String key) async {}
}

void main() {
  late List<FlutterErrorDetails> reported;
  late FlutterExceptionHandler? previousOnError;

  setUp(() {
    reported = [];
    previousOnError = FlutterError.onError;
    FlutterError.onError = reported.add;
  });

  tearDown(() {
    FlutterError.onError = previousOnError;
  });

  test('a persist error reaches FlutterError.onError with library, exception, stack and context', () async {
    final storage = _FailingBackend(observer: const FlutterErrorSettingsObserver())..setString('k', 'v');
    await expectLater(storage.flush(), throwsA(isA<SettingsPersistException>()));

    final details = reported.single;
    expect(details.library, 'typed_settings');
    expect(details.exception, isA<StateError>());
    expect(details.stack, isNotNull);
    expect(details.context.toString(), contains('`k`'));
  });

  test('a read fallback reaches FlutterError.onError', () {
    final storage = InMemoryStorage(observer: const FlutterErrorSettingsObserver())..setString('k', '::not a uri::');
    final setting = UriSetting(
      storage: storage,
      key: 'k',
      defaultValue: Uri.parse('https://example.com'),
    );

    expect(setting.value, Uri.parse('https://example.com'));
    final details = reported.single;
    expect(details.exception, isA<FormatException>());
    expect(details.context.toString(), contains('`k`'));
  });

  test('a storage created without it does not report through FlutterError', () {
    final storage = InMemoryStorage()..setString('k', 'text');

    expect(storage.getInt('k'), isNull);
    expect(reported, isEmpty);
  });
}
