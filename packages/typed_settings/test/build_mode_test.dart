@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:typed_settings/src/foundation/build_mode.dart';

void main() {
  test('tests run as a debug build', () {
    expect(isDebugBuild, isTrue);
  });

  group('a Dart program', () {
    late Directory dir;
    late File script;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('typed_settings_build_mode');
      script = File('${dir.path}/print_build_mode.dart')
        ..writeAsStringSync('''
import 'package:typed_settings/src/foundation/build_mode.dart';

void main() => print(isDebugBuild);
''');
    });

    tearDown(() => dir.deleteSync(recursive: true));

    Future<String> run(List<String> flags) async {
      final packages = await Isolate.packageConfig;
      final result = await Process.run(Platform.resolvedExecutable, [
        ...flags,
        '--packages=${packages!.toFilePath()}',
        script.path,
      ]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return (result.stdout as String).trim();
    }

    test('run as `dart run` does, without assertions, is not a debug build, so it shows no stored data', () async {
      expect(await run(const []), 'false');
    });

    test('run with assertions is a debug build', () async {
      expect(await run(const ['--enable-asserts']), 'true');
    });
  });
}
