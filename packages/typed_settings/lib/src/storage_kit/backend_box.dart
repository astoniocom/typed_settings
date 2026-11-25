import 'package:meta/meta.dart';

/// A box of a backend: the part of it that one open storage serves alone.
///
/// [backend] is what the storage persists through (a DAO's store, a Hive
/// box, the shared preferences), told apart by `==`: identity for most
/// objects, while a value that names the persistence (a table) makes two
/// objects writing to it one backend. [name] is the box within it; `''`
/// for the unnamed box, or for a backend that is one box itself. Two
/// boxes are equal when both are.
@immutable
final class BackendBox {
  /// The box [name] of [backend].
  const BackendBox(this.backend, [this.name = '']);

  /// What the storage persists through.
  final Object backend;

  /// The box within [backend]; `''` for the unnamed box.
  final String name;

  @override
  bool operator ==(Object other) => other is BackendBox && other.backend == backend && other.name == name;

  @override
  int get hashCode => Object.hash(backend, name);
}

/// The boxes that open storages serve, without keeping a backend alive.
///
/// A storage that is dropped without `close` stays listed: creating
/// another one over its box still throws for as long as the backend can
/// be named. The list only stops holding the backend itself, so that a
/// forgotten storage does not pin what it persisted through (a DAO and its
/// database) for the life of
/// the isolate. Once nothing else references the backend, no storage can
/// be created over it either, and its boxes leave the list.
///
/// A backend that cannot be referenced weakly (a string or a number that
/// names a table, a record) is held as it is: such a value is small and
/// can be written again at any time, so its boxes stay listed until
/// closed. A backend object compared by value (a class with `==`) is
/// listed for as long as the instance a storage was created with lives:
/// an open storage holds it, so a second open storage is always rejected.
@internal
final class ServedBoxes {
  final List<_ServedBox> _boxes = [];

  /// Lists [box]; `false`, and no change, when it is listed already.
  bool add(BackendBox box) {
    _boxes.removeWhere((served) => served.isGone);
    if (_boxes.any((served) => served.isBox(box))) return false;
    _boxes.add(_ServedBox(box));
    return true;
  }

  /// Takes [box] out; a no-op when it is not listed.
  void remove(BackendBox box) => _boxes.removeWhere((served) => served.isGone || served.isBox(box));
}

/// One box in [ServedBoxes]: its name and its backend, the latter held
/// weakly where the language allows it.
final class _ServedBox {
  _ServedBox(BackendBox box)
    : _name = box.name,
      _weakBackend = _canBeHeldWeakly(box.backend) ? WeakReference(box.backend) : null,
      _strongBackend = _canBeHeldWeakly(box.backend) ? null : box.backend;

  final String _name;
  final WeakReference<Object>? _weakBackend;
  final Object? _strongBackend;

  /// What a [WeakReference] accepts: not a number, a string, a bool or a
  /// record, which have no identity to outlive.
  static bool _canBeHeldWeakly(Object backend) =>
      backend is! num && backend is! String && backend is! bool && backend is! Record;

  Object? get _backend => _strongBackend ?? _weakBackend?.target;

  /// Whether the backend was collected, so that no storage serves this
  /// box and none can be created over it.
  bool get isGone => _backend == null;

  /// Whether this is [box]: the same name, and a backend equal to its.
  bool isBox(BackendBox box) => _name == box.name && _backend == box.backend;
}
