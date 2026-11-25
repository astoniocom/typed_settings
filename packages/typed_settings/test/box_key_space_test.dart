import 'package:test/test.dart';
import 'package:typed_settings/typed_settings_backend.dart';

void main() {
  test('a box name with the separator is an ArgumentError', () {
    expect(() => BoxKeySpace('a.b'), throwsArgumentError);
  });

  test('a box name with the escape character is an ArgumentError: its keys would be keys of the unnamed box', () {
    expect(() => BoxKeySpace(r'a\'), throwsArgumentError);
    expect(() => BoxKeySpace(r'a\b'), throwsArgumentError);
    expect(BoxKeySpace('').storedKey('a.x'), r'a\.x', reason: r'what the key `x` of a box `a\` would be stored as');
  });

  test('a named box prefixes its keys and escapes their dots and backslashes', () {
    final user = BoxKeySpace('user');

    expect(user.storedKey('age'), 'user.age');
    expect(user.storedKey('a.b'), r'user.a\.b');
    expect(user.storedKey(r'a\b'), r'user.a\\b');
  });

  test('the unnamed box escapes its keys, so a dotted one is not a named box key', () {
    final rest = BoxKeySpace('');

    expect(rest.storedKey('user.age'), r'user\.age');
    expect(rest.settingKey(rest.storedKey('user.age')), 'user.age');
    expect(rest.settingKey('user.age'), isNull);
    expect(BoxKeySpace('user').settingKey(rest.storedKey('user.age')), isNull);
  });

  test('a stored key of the box gives back the setting key', () {
    for (final box in ['', 'user']) {
      final space = BoxKeySpace(box);
      for (final key in ['age', 'a.b', r'a\b', r'a\.b', r'trailing\']) {
        final stored = space.storedKey(key);
        expect(space.settingKey(stored), key, reason: '`$key` in `$box`');
      }
    }
  });
}
