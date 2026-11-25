@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:test/test.dart';

/// What a class of `lib/src/settings` or `lib/src/settings/presets` declares:
/// the class it extends, the named parameters of its unnamed constructor
/// and every parameter of its `inSlot` constructor.
typedef _Declared = ({String? superclass, Set<String> parameters, Set<String> inSlot});

void main() {
  late Map<String, _Declared> classes;
  late List<String> presets;

  // The sources are read rather than the presets listed, so that a new
  // preset is checked without being registered here.
  setUpAll(() async {
    final settings = await Isolate.resolvePackageUri(Uri.parse('package:typed_settings/src/settings/'));
    final files = Directory.fromUri(
      settings!,
    ).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart'));
    classes = {
      for (final file in files)
        for (final declaration in parseFile(
          path: file.path,
          featureSet: FeatureSet.latestLanguageVersion(),
        ).unit.declarations.whereType<ClassDeclaration>())
          declaration.namePart.typeName.lexeme: (
            superclass: declaration.extendsClause?.superclass.name.lexeme,
            parameters: _parameters(declaration, constructor: null, namedOnly: true),
            inSlot: _parameters(declaration, constructor: 'inSlot', namedOnly: false),
          ),
    };
    bool isPreset(String name) {
      for (var current = classes[name]?.superclass; current != null; current = classes[current]?.superclass) {
        if (current == 'StoredSetting') return true;
      }
      return false;
    }

    presets = [...classes.keys.where(isPreset)];
  });

  test('are all found', () {
    expect(presets, containsAll(['IntSetting', 'EnumNullableSetting', 'IntListSetting', 'StoredNullableSetting']));
  });

  test('take every option of StoredSetting, so that they gain the ones it gains', () {
    const strategies = {'codec', 'equality', 'snapshot'};
    const keyed = {'storage', 'key', 'legacyKeys'};
    final options = classes['StoredSetting']!.parameters.difference(strategies);
    expect(options, {'slot', 'defaultValue', 'validator'});
    expect(options.intersection(keyed), isEmpty);

    expect(
      classes['StoredNullableSetting']!.parameters,
      containsAll(options),
      reason: 'StoredNullableSetting is a building block like StoredSetting, over a slot',
    );

    for (final preset in presets.where((name) => name != 'StoredNullableSetting')) {
      final declared = classes[preset]!;
      expect(
        declared.parameters,
        containsAll({
          ...options.difference({'slot'}),
          ...keyed,
        }),
        reason: '$preset must take a storage and a key, and forward every other option of StoredSetting',
      );
      expect(
        declared.parameters,
        isNot(contains('slot')),
        reason: '$preset must not make a caller pick the slot of its raw type',
      );
      expect(
        declared.inSlot,
        containsAll(options),
        reason: '$preset.inSlot must forward every option of StoredSetting',
      );
    }
  });
}

Set<String> _parameters(ClassDeclaration declaration, {required String? constructor, required bool namedOnly}) {
  final declared = declaration.body.members
      .whereType<ConstructorDeclaration>()
      .where((member) => member.name?.lexeme == constructor)
      .singleOrNull;
  return {
    for (final parameter in declared?.parameters.parameters ?? const <FormalParameter>[])
      if (parameter case FormalParameter(:final isNamed, name: final name?) when isNamed || !namedOnly) name.lexeme,
  };
}
