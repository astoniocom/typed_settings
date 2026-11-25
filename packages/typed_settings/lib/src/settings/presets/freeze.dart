/// Immutable snapshots of collection values.
///
/// Used as the `snapshot` strategy of collection-valued settings so that
/// the value a setting caches and exposes shares no mutable state with the
/// caller's object or with a storage's internal state. Exported so that
/// applications can pass them as `snapshotElement` of a `ListSetting`
/// whose elements are themselves collections.
library;

/// Deep-copies a JSON-like map (maps, lists, scalars) into unmodifiable
/// collections; keys are stringified.
Map<String, Object?> freezeJsonMap(Map<Object?, Object?> map) {
  return Map<String, Object?>.unmodifiable(<String, Object?>{
    for (final entry in map.entries) entry.key.toString(): _freezeJson(entry.value),
  });
}

/// An unmodifiable copy of [list]. Elements are shared unless [element]
/// is given, in which case each element is passed through it first; use a
/// copying function for mutable element types.
List<T> freezeList<T>(List<T> list, [T Function(T element)? element]) =>
    List<T>.unmodifiable(element == null ? list : list.map(element));

Object? _freezeJson(Object? value) {
  return switch (value) {
    final Map<Object?, Object?> map => freezeJsonMap(map),
    final List<Object?> list => List<Object?>.unmodifiable(list.map(_freezeJson)),
    _ => value,
  };
}
