@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

/// What each top-level entry of `lib/src` may import, besides itself.
///
/// The entries form a hierarchy: an entry lists only entries listed before
/// it, so no two of them depend on each other.
const _allowed = <String, Set<String>>{
  'foundation': {},
  'codec': {'foundation'},
  'validation': {'foundation'},
  'diagnostics': {'foundation', 'validation'},
  'storage_kit': {'foundation', 'validation', 'diagnostics'},
  'storage': {'foundation', 'validation', 'diagnostics', 'storage_kit'},
  'slot': {'foundation', 'validation', 'diagnostics', 'storage'},
  'settings': {'foundation', 'codec', 'validation', 'diagnostics', 'storage', 'slot'},
};

/// Files held to a narrower set of entries than the rest of their own entry.
///
/// `typed_settings_contract.dart` exports `Setting` to code that edits
/// settings without owning a storage, so `Setting` must not pull one in.
const _narrowed = <String, Set<String>>{
  'settings/setting.dart': {'validation'},
};

void main() {
  late Map<String, Set<String>> imports;

  setUpAll(() async {
    imports = await _sourceImports();
  });

  test('the allowed dependencies form a hierarchy', () {
    final order = _allowed.keys.toList();
    for (final MapEntry(key: entry, value: dependencies) in _allowed.entries) {
      for (final dependency in dependencies) {
        expect(order.indexOf(dependency), lessThan(order.indexOf(entry)), reason: '$entry -> $dependency');
      }
    }
  });

  test('every entry of lib/src has a place in the hierarchy', () {
    expect({for (final file in imports.keys) _entryOf(file)}, unorderedEquals(_allowed.keys));
  });

  test('a file imports only the entries below its own', () {
    for (final MapEntry(key: file, value: uris) in imports.entries) {
      final entry = _entryOf(file);
      for (final uri in uris) {
        final target = _entryOf(uri);
        if (target == entry) continue;
        expect(_allowed[entry], contains(target), reason: '$file imports $uri');
      }
    }
  });

  test('a narrowed file imports only its own allowed entries', () {
    for (final MapEntry(key: file, value: allowed) in _narrowed.entries) {
      expect(imports, contains(file));
      for (final uri in imports[file]!) {
        expect(allowed, contains(_entryOf(uri)), reason: '$file imports $uri');
      }
    }
  });

  test('no files import each other, directly or through others', () {
    final visiting = <String>[];
    final done = <String>{};
    void visit(String file) {
      if (done.contains(file)) return;
      final cycleStart = visiting.indexOf(file);
      if (cycleStart >= 0) fail('import cycle: ${[...visiting.sublist(cycleStart), file].join(' -> ')}');
      visiting.add(file);
      imports[file]!.forEach(visit);
      visiting.removeLast();
      done.add(file);
    }

    imports.keys.forEach(visit);
  });
}

String _entryOf(String file) => file.split('/').first;

/// The files of `lib/src`, relative to it, each with the `lib/src` files it
/// imports or exports.
Future<Map<String, Set<String>>> _sourceImports() async {
  final src = await Isolate.resolvePackageUri(Uri.parse('package:typed_settings/src/'));
  final imports = <String, Set<String>>{};
  for (final file in Directory.fromUri(src!).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final directives = parseFile(
      path: file.path,
      featureSet: FeatureSet.latestLanguageVersion(),
    ).unit.directives.whereType<UriBasedDirective>();
    imports[file.uri.path.substring(src.path.length)] = {
      for (final directive in directives) file.uri.resolve(directive.uri.stringValue!),
    }.map((uri) => _sourcePath(uri, src)).whereType<String>().toSet();
  }
  return imports;
}

String? _sourcePath(Uri uri, Uri src) {
  const package = 'package:typed_settings/src/';
  final text = uri.toString();
  if (text.startsWith(package)) return text.substring(package.length);
  if (uri.isScheme('file') && uri.path.startsWith(src.path)) return uri.path.substring(src.path.length);
  return null;
}
