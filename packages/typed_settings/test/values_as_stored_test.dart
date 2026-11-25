import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

enum _Mode { a, b, c }

/// Stores an int as it is but gives back only even ones: an odd raw value
/// is rejected with a [FormatException], or with a [StateError] (a bug)
/// when [buggy].
class _EvenOnlyCodec implements SettingCodec<int, int> {
  const _EvenOnlyCodec({this.buggy = false});

  final bool buggy;

  @override
  int decode(int raw) {
    if (raw.isEven) return raw;
    if (buggy) throw StateError('bug');
    throw FormatException('odd', raw);
  }

  @override
  int encode(int value) => value;
}

void main() {
  late InMemoryStorage storage;

  setUp(() => storage = InMemoryStorage());

  group('DateTimeSetting', () {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final utc = DateTime.utc(2026, 11, 3, 12, 30, 15, 250, 999);
    final stored = DateTime.fromMillisecondsSinceEpoch(utc.millisecondsSinceEpoch);

    test('holds an assigned value as the storage gives it back: local time, whole milliseconds', () {
      final setting = DateTimeSetting(storage: storage, key: 'k', defaultValue: epoch)..value = utc;

      expect(setting.value, stored);
      expect(setting.value.isUtc, isFalse);
      setting.invalidate();
      expect(setting.value, stored, reason: 'the same value is read after a restart');
    });

    test('assigning the held moment in another time zone is a no-op', () {
      final setting = DateTimeSetting(storage: storage, key: 'k', defaultValue: epoch)..value = utc;
      var notified = 0;
      setting.addListener(() => notified++);
      var written = 0;
      storage.addKeyListener('k', () => written++);

      setting.value = utc.toLocal();
      setting.value = utc;

      expect(notified, 0);
      expect(written, 0);
    });

    test('defaultValue is held as the storage gives it back, so the stored default counts as the default', () {
      storage.setInt('k', utc.millisecondsSinceEpoch);
      final setting = DateTimeSetting(storage: storage, key: 'k', defaultValue: utc);

      expect(setting.defaultValue, stored);
      expect(setting.isDefault, isTrue);
    });
  });

  group('DurationSetting', () {
    const assigned = Duration(microseconds: 1500);
    const stored = Duration(milliseconds: 1);

    test('drops sub-millisecond precision as soon as a value is assigned or committed', () async {
      final setting = DurationSetting(storage: storage, key: 'k', defaultValue: Duration.zero)..value = assigned;
      expect(setting.value, stored);

      setting.reset();
      await setting.commit(assigned);
      expect(setting.value, stored);
      expect(storage.getInt('k'), 1);
    });

    test('validates the value as stored', () {
      final setting = DurationSetting(
        storage: storage,
        key: 'k',
        defaultValue: const Duration(seconds: 1),
        validator: SettingValidator.noneOf({Duration.zero}),
      );
      const roundsToZero = Duration(microseconds: 999);

      expect(setting.validate(roundsToZero), isA<ForbiddenValueValidationError<Duration>>());
      expect(() => setting.value = roundsToZero, throwsA(isA<SettingValidationException>()));
    });

    test('a nullable setting holds its values and default as stored and keeps null', () {
      final setting = DurationNullableSetting(storage: storage, key: 'k', defaultValue: assigned);
      expect(setting.defaultValue, stored);

      setting.value = const Duration(microseconds: 2500);
      expect(setting.value, const Duration(milliseconds: 2));

      setting.value = null;
      expect(setting.value, isNull);
    });
  });

  test('a value the codec cannot give back is rejected when assigned, before anything is written', () async {
    final setting = EnumSetting<_Mode>(
      storage: storage,
      key: 'k',
      defaultValue: _Mode.a,
      values: const [_Mode.a, _Mode.b],
    );
    var notified = 0;
    setting.addListener(() => notified++);

    expect(() => setting.value = _Mode.c, throwsFormatException);
    expect(() => setting.validate(_Mode.c), throwsFormatException);
    await expectLater(setting.commit(_Mode.c), throwsFormatException);

    expect(setting.value, _Mode.a);
    expect(storage.getString('k'), isNull);
    expect(notified, 0);
  });

  test('commit of a value equal to the held one writes the held one, so memory and storage agree', () async {
    storage.setString('k', 'Foo');
    final setting = StoredSetting<String, String>(
      slot: KeyedSettingSlot.ofString(storage, key: 'k'),
      defaultValue: '',
      codec: const IdentityCodec(),
      equality: (a, b) => a.toLowerCase() == b.toLowerCase(),
    );

    await setting.commit('foo');

    expect(setting.value, 'Foo');
    expect(storage.getString('k'), 'Foo');
  });

  group('a defaultValue the codec cannot give back', () {
    test('is an ArgumentError, thrown before the setting registers with the storage', () {
      expect(
        () => StoredSetting<int, int>(
          slot: KeyedSettingSlot.ofInt(storage, key: 'k'),
          defaultValue: 3,
          codec: const _EvenOnlyCodec(),
        ),
        throwsArgumentError,
      );
      expect(
        () => StringSetting(storage: storage, key: 'k', defaultValue: ''),
        returnsNormally,
        reason: 'no int setting holds the key',
      );
    });

    test('propagates an Error of the codec as a bug', () {
      expect(
        () => StoredSetting<int, int>(
          slot: KeyedSettingSlot.ofInt(storage, key: 'k'),
          defaultValue: 3,
          codec: const _EvenOnlyCodec(buggy: true),
        ),
        throwsStateError,
      );
    });
  });
}
