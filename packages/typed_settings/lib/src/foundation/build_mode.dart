/// Whether this is a debug build: the one build in which diagnostics show
/// the stored data they refer to, and in which type names are not
/// minified.
///
/// A debug build is one that runs with assertions: Flutter in debug mode,
/// and `dart test`. Flutter's profile and release builds, `dart run` and a
/// compiled executable run without them, unless started with
/// `--enable-asserts`. The flags Flutter's `kDebugMode` reads are not set
/// by `dart run`, which would show stored data in a production run of a
/// Dart program.
final bool isDebugBuild = () {
  var asserting = false;
  assert(asserting = true, 'only evaluated with assertions enabled');
  return asserting;
}();
