import 'package:test/test.dart';
import 'package:typed_settings/typed_settings.dart';
import 'package:typed_settings/typed_settings_in_memory.dart';

void main() {
  group('SettingValidator', () {
    test('the default constructor applies one check on read and write', () {
      const error = ForbiddenValueValidationError(0);
      final validator = SettingValidator<int>((v) => v == 0 ? error : null);

      expect(validator.validateRead(0), error);
      expect(validator.validateWrite(0), error);
      expect(validator.validateRead(1), isNull);
      expect(validator.validateWrite(1), isNull);
    });

    test('split: the write guard runs before the invariant and only on write', () {
      const readError = ForbiddenValueValidationError('read');
      const writeError = ForbiddenValueValidationError('write');
      final validator = SettingValidator<int>.split(
        invariant: (v) => v < 0 ? readError : null,
        writeGuard: (v) => v == -1 ? writeError : null,
      );

      expect(validator.validateRead(-1), readError);
      expect(validator.validateWrite(-1), writeError, reason: 'write guard first');
      expect(validator.validateWrite(-2), readError, reason: 'then the invariant');
      expect(validator.validateWrite(1), isNull);
    });

    test('all: first error wins; on write every guard runs before any invariant', () {
      const guard = ForbiddenValueValidationError('guard');
      const invariant = ForbiddenValueValidationError('invariant');
      final validator = SettingValidator<int>.all([
        SettingValidator((v) => v > 5 ? invariant : null),
        SettingValidator.split(writeGuard: (v) => v > 10 ? guard : null),
      ]);

      expect(validator.validateRead(11), invariant, reason: 'write guards do not apply on read');
      expect(validator.validateWrite(11), guard, reason: 'the later guard still precedes the earlier invariant');
      expect(validator.validateWrite(6), invariant);
      expect(validator.validateWrite(1), isNull);
    });

    test('all: each check runs at most once per validation', () {
      var reads = 0;
      var writes = 0;
      final validator = SettingValidator<int>.all([
        SettingValidator.split(
          invariant: (v) {
            reads++;
            return null;
          },
          writeGuard: (v) {
            writes++;
            return null;
          },
        ),
      ]);

      validator.validateWrite(1);

      expect(reads, 1);
      expect(writes, 1);
    });

    test('a subclass can name a validator and pass its checks to super', () {
      final validator = _MaxLength(3);
      expect(validator.validateRead('abcd'), isA<ForbiddenValueValidationError<String>>());
      expect(validator.validateWrite('abc'), isNull);
    });
  });

  group('built-in checks', () {
    test('notNull rejects null with RequiredValidationError', () {
      final validator = SettingValidator.notNull<int?>(debugDescription: 'pick one');
      expect(validator.validateRead(null), const RequiredValidationError(debugDescription: 'pick one'));
      expect(validator.validateRead(0), isNull);
    });

    test('range rejects values outside the inclusive bounds and reports them', () {
      final validator = SettingValidator.range<int>(min: 0, max: 10);
      expect(validator.validateRead(0), isNull);
      expect(validator.validateRead(10), isNull);
      expect(validator.validateRead(-1), const RangeValidationError(min: 0, max: 10, actual: -1));
      expect(validator.validateRead(11), const RangeValidationError(min: 0, max: 10, actual: 11));
    });

    test('range accepts an open bound and a nullable type, where null passes', () {
      final atLeastZero = SettingValidator.range<double?>(min: 0);
      expect(atLeastZero.validateRead(null), isNull);
      expect(atLeastZero.validateRead(1000000000), isNull);
      expect(atLeastZero.validateRead(-0.5), const RangeValidationError(min: 0, actual: -0.5));

      final atMostTen = SettingValidator.range<int>(max: 10);
      expect(atMostTen.validateRead(11), const RangeValidationError(max: 10, actual: 11));
    });

    test('range rejects no bound and inverted bounds with an ArgumentError', () {
      expect(() => SettingValidator.range<int>(), throwsArgumentError);
      expect(() => SettingValidator.range<int>(min: 2, max: 1), throwsArgumentError);
    });

    test('pattern rejects a non-matching string and reports the pattern source', () {
      final validator = SettingValidator.pattern<String>(RegExp(r'^[a-z]+$'));
      expect(validator.validateRead('abc'), isNull);
      expect(validator.validateRead('Abc'), const PatternValidationError(pattern: r'^[a-z]+$', actual: 'Abc'));
    });

    test('pattern lets null pass for a nullable type', () {
      final validator = SettingValidator.pattern<String?>(RegExp('x'));
      expect(validator.validateRead(null), isNull);
    });

    test('noneOf rejects listed values with ForbiddenValueValidationError', () {
      final validator = SettingValidator.noneOf<String>({'root', 'admin'}, debugDescription: 'reserved');
      expect(validator.validateRead('root'), const ForbiddenValueValidationError('root', debugDescription: 'reserved'));
      expect(validator.validateRead('alice'), isNull);
    });

    test('built-in checks compose with all and work through a setting', () {
      final storage = InMemoryStorage();
      final setting = IntNullableSetting(
        storage: storage,
        key: 'k',
        validator: SettingValidator.all([
          SettingValidator.split(writeGuard: SettingValidator.notNull<int?>().validateRead),
          SettingValidator.range(min: 1, max: 5),
        ]),
      );

      expect(setting.validate(null), isA<RequiredValidationError>(), reason: 'null may be held, not persisted');
      expect(setting.value, isNull, reason: 'the null default passes the invariant');
      expect(setting.validate(0), isA<RangeValidationError>());
      expect(setting.validate(3), isNull);
      setting.value = 3;
      expect(storage.getInt('k'), 3);
    });
  });
}

/// A named validator: fields plus checks handed to the base class.
final class _MaxLength extends SettingValidator<String> {
  _MaxLength(this.max) : super((value) => value.length > max ? ForbiddenValueValidationError(value) : null);

  final int max;
}
