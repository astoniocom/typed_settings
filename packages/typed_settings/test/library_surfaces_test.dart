@TestOn('vm')
library;

import 'dart:isolate';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

void main() {
  test('the application library does not export what builds a setting of a new kind', () async {
    final exported = await _exports('typed_settings.dart');

    expect(
      exported.where(
        (uri) =>
            uri.startsWith('src/codec/') || uri.startsWith('src/slot/') || uri.startsWith('src/settings/internal/'),
      ),
      isEmpty,
    );
    expect(
      exported,
      isNot(
        anyOf(
          contains('src/settings/stored_setting.dart'),
          contains('src/settings/stored_nullable_setting.dart'),
          contains('src/settings/settings_registry.dart'),
        ),
      ),
    );
  });

  test('the contract library does not export storage or diagnostics', () async {
    final exported = await _exports('typed_settings_contract.dart');

    expect(
      exported.where((uri) => uri.startsWith('src/storage/') || uri.startsWith('src/diagnostics/')),
      unorderedEquals(['src/diagnostics/settings_persist_exception.dart', 'src/diagnostics/settings_event.dart']),
      reason: 'a commit fails with SettingsPersistException, so code that commits needs it and its failures',
    );
    expect(await _shown('typed_settings_contract.dart', 'src/diagnostics/settings_event.dart'), [
      'PersistErrorEvent',
    ], reason: 'only the type of the failures a SettingsPersistException carries');
  });

  test('disposing a setting is for the code that creates it, not for code that only edits it', () async {
    expect(await _exports('typed_settings_contract.dart'), isNot(contains('src/settings/owned_setting.dart')));
    expect(await _exports('typed_settings.dart'), contains('src/settings/owned_setting.dart'));
  });
}

Future<List<String>> _exports(String library) async => [
  for (final directive in await _exportDirectives(library)) directive.uri.stringValue!,
];

/// The names [library] lets through from [exported] with `show`; empty
/// when it exports all of it.
Future<List<String>> _shown(String library, String exported) async {
  final directive = (await _exportDirectives(library)).singleWhere((d) => d.uri.stringValue == exported);
  return [
    for (final combinator in directive.combinators.whereType<ShowCombinator>())
      for (final name in combinator.shownNames) name.name,
  ];
}

Future<Iterable<ExportDirective>> _exportDirectives(String library) async {
  final uri = await Isolate.resolvePackageUri(Uri.parse('package:typed_settings/$library'));
  return parseFile(
    path: uri!.toFilePath(),
    featureSet: FeatureSet.latestLanguageVersion(),
  ).unit.directives.whereType<ExportDirective>();
}
