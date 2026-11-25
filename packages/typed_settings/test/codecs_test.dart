import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_extend.dart';

enum _Tier { basic, pro }

/// A level wrapping a tier, for chaining with the tier's codec.
@immutable
final class _Level {
  const _Level(this.tier);

  final _Tier tier;

  @override
  bool operator ==(Object other) => other is _Level && other.tier == tier;

  @override
  int get hashCode => tier.hashCode;
}

final class _LevelCodec implements SettingCodec<_Level, _Tier> {
  const _LevelCodec();

  @override
  _Level decode(_Tier raw) => _Level(raw);

  @override
  _Tier encode(_Level value) => value.tier;
}

void main() {
  group('JsonObjectCodec', () {
    final codec = JsonObjectCodec<Map<String, Object?>>(fromJson: Map.of, toJson: (value) => value);

    test('stores a JSON object and reads it back', () {
      expect(codec.encode({'a': 1}), '{"a":1}');
      expect(codec.decode('{"a":1}'), {'a': 1});
    });

    test('rejects JSON that is not an object, and text that is not JSON', () {
      expect(() => codec.decode('[1]'), throwsFormatException);
      expect(() => codec.decode('{'), throwsFormatException);
    });
  });

  group('ParsedStringCodec', () {
    const codec = ParsedStringCodec<BigInt>(parse: BigInt.parse, format: _decimal);

    test('stores what format gives and reads it with parse', () {
      final big = BigInt.parse('123456789012345678901234567890');
      expect(codec.encode(big), '123456789012345678901234567890');
      expect(codec.decode(codec.encode(big)), big);
    });

    test('lets the FormatException of parse through', () {
      expect(() => codec.decode('twelve'), throwsFormatException);
    });
  });

  group('then', () {
    final codec = const _LevelCodec().then(EnumNameCodec(_Tier.values));

    test('encodes through the first codec, then the second, and decodes in reverse', () {
      expect(codec, isA<ChainedCodec<_Level, _Tier, String>>());
      expect(codec.encode(const _Level(_Tier.pro)), 'pro');
      expect(codec.decode('basic'), const _Level(_Tier.basic));
    });

    test('lets what the second codec throws through', () {
      expect(() => codec.decode('gold'), throwsFormatException);
    });
  });

  group('JsonSetCodec', () {
    const codec = JsonSetCodec<int>(fromJson: _int, toJson: _identity);

    test('stores the elements in iteration order and reads a duplicate once', () {
      expect(codec.encode({3, 1}), '[3,1]');
      expect(codec.decode('[1,2,1]'), {1, 2});
    });

    test('rejects JSON that is not an array', () {
      expect(() => codec.decode('{"a":1}'), throwsFormatException);
    });
  });

  group('CalendarDateCodec', () {
    const codec = CalendarDateCodec();

    test('stores the date as the value shows it, padded', () {
      expect(codec.encode(DateTime(7, 3, 4, 23, 59)), '0007-03-04');
      expect(codec.encode(DateTime.utc(2024, 12, 31, 23)), '2024-12-31', reason: 'the UTC date of a UTC value');
    });

    test('reads local midnight of the date', () {
      final date = codec.decode('2024-02-29');
      expect(date, DateTime(2024, 2, 29));
      expect(date.isUtc, isFalse);
    });

    test('rejects a string that is not a day of the calendar', () {
      for (final raw in ['2024-02-30', '2023-02-29', '2024-13-01', '2024-1-01', '24-01-01', '2024-01-01T00:00']) {
        expect(() => codec.decode(raw), throwsFormatException, reason: raw);
      }
    });

    test('rejects a year that yyyy cannot hold', () {
      expect(() => codec.encode(DateTime(10000)), throwsArgumentError);
      expect(() => codec.encode(DateTime(-1)), throwsArgumentError);
    });
  });

  group('Base64BytesCodec', () {
    const codec = Base64BytesCodec();

    test('stores bytes as Base64 and reads them back', () {
      final bytes = Uint8List.fromList([0, 1, 254, 255]);
      expect(codec.encode(bytes), 'AAH+/w==');
      expect(codec.decode('AAH+/w=='), bytes);
      expect(codec.decode('AAH-_w=='), bytes, reason: 'the URL-safe alphabet is read too');
    });

    test('rejects a string that is not Base64', () {
      expect(() => codec.decode('not base64!'), throwsFormatException);
    });
  });
}

String _decimal(BigInt value) => value.toString();

int _int(Object? json) => json! as int;

Object? _identity(int element) => element;
