import 'package:meta/meta.dart';
import 'package:typed_settings/src/storage_kit/key_mapping.dart';

/// The keys of one box among several that share a flat key space: the
/// named box `user` stores the setting key `age` as `user.age`, the
/// unnamed box (`''`) stores it as `age`.
///
/// A box name must not contain the [separator] `.` or the escape
/// character `\`; a setting key may contain both. A name ending in `\`
/// would turn the separator after it into an escaped `.`, and so into a
/// key of the unnamed box.
/// `\` and `.` of a setting key are escaped before the prefix is added,
/// so that a dotted key is never read as the key of another box: the key
/// `user.age` of the unnamed box is stored as `user\.age`, not as the key
/// `age` of the box `user`. The unnamed box owns the stored keys without
/// an unescaped `.`.
@immutable
final class BoxKeySpace implements KeyMapping {
  /// The keys of [box]; an [ArgumentError] when it contains [separator]
  /// or `\`.
  BoxKeySpace(this.box) {
    if (box.contains(separator) || box.contains(_escape)) {
      throw ArgumentError.value(box, 'box', 'must not contain `$separator` or `$_escape`');
    }
  }

  /// What escapes a `.` or itself in a setting key.
  static const String _escape = r'\';

  /// What separates a box from its key in the stored key.
  static const String separator = '.';

  /// The box name; `''` for the unnamed box.
  final String box;

  @override
  String storedKey(String key) {
    final escaped = key.replaceAll(_escape, '$_escape$_escape').replaceAll(separator, '$_escape$separator');
    return box.isEmpty ? escaped : '$box$separator$escaped';
  }

  /// The setting key of [storedKey], or `null` when it belongs to another
  /// box: the unnamed box owns the stored keys without an unescaped `.`, a
  /// named one those that start with its prefix.
  @override
  String? settingKey(String storedKey) {
    if (box.isEmpty) return _hasUnescapedSeparator(storedKey) ? null : _unescape(storedKey);
    final prefix = '$box$separator';
    return storedKey.startsWith(prefix) ? _unescape(storedKey.substring(prefix.length)) : null;
  }

  static String _unescape(String stored) {
    final buffer = StringBuffer();
    for (var i = 0; i < stored.length; i++) {
      final char = stored[i];
      if (char == _escape && i + 1 < stored.length) {
        buffer.write(stored[i + 1]);
        i++;
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  static bool _hasUnescapedSeparator(String stored) {
    for (var i = 0; i < stored.length; i++) {
      final char = stored[i];
      if (char == _escape) {
        i++;
        continue;
      }
      if (char == separator) return true;
    }
    return false;
  }
}
