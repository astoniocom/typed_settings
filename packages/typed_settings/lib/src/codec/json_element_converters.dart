/// Element converters shared by the built-in `ListSetting` presets.
library;

/// Reads a JSON number as an `int`. Integral doubles (`2.0`, as some JSON
/// producers emit) are accepted; anything else throws a [FormatException].
int intFromJson(Object? json) {
  if (json is int) return json;
  if (json is double && json.isFinite && json == json.truncateToDouble()) return json.toInt();
  throw FormatException('Expected an integer element, got ${json.runtimeType}', '$json');
}

/// Reads a JSON string; anything else throws a [FormatException].
String stringFromJson(Object? json) {
  if (json is String) return json;
  throw FormatException('Expected a string element, got ${json.runtimeType}', '$json');
}

/// `toJson` for elements that are JSON values already.
Object? jsonIdentity<T>(T element) => element;
