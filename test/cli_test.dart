import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;
import 'package:test_process/test_process.dart';

void main() {
  const unsortedCode = '''
class Example {
  void zMethod() {}

  Example();

  int aField = 1;

  static int sField = 2;

  void aMethod() {}
}
''';

  const sortedCodeDefault = '''
class Example {
  static int sField = 2;

  int aField = 1;

  Example();

  void aMethod() {}

  void zMethod() {}
}
''';

  const sortedCodeConstructorsFirst = '''
class Example {
  Example();

  static int sField = 2;

  int aField = 1;

  void aMethod() {}

  void zMethod() {}
}
''';

  group('CLI integration', () {
    test(
      'default mode emits sorted code to stdout and leaves file unchanged',
      () async {
        await d.file('test_file.dart', unsortedCode).create();
        final filePath = p.join(d.sandbox, 'test_file.dart');

        final process = await TestProcess.start('dart', [
          'run',
          'bin/sort_dart_members.dart',
          filePath,
        ]);

        final stdoutOutput = await process.stdoutStream().join('\n');
        await process.shouldExit(0);

        expect(stdoutOutput.trim(), equals(sortedCodeDefault.trim()));

        // Verify file on disk is not changed
        final onDisk = File(filePath).readAsStringSync();
        expect(onDisk, equals(unsortedCode));
      },
    );

    test('--check on unsorted file exits 1 and emits to stderr', () async {
      await d.file('unsorted.dart', unsortedCode).create();
      final filePath = p.join(d.sandbox, 'unsorted.dart');

      final process = await TestProcess.start('dart', [
        'run',
        'bin/sort_dart_members.dart',
        '--check',
        filePath,
      ]);

      final stderrOutput = await process.stderrStream().join('\n');
      await process.shouldExit(1);

      expect(stderrOutput.trim(), equals('File is not sorted'));
    });

    test(
      '--check on already-sorted file exits 0 and emits to stdout',
      () async {
        await d.file('sorted.dart', sortedCodeDefault).create();
        final filePath = p.join(d.sandbox, 'sorted.dart');

        final process = await TestProcess.start('dart', [
          'run',
          'bin/sort_dart_members.dart',
          '--check',
          filePath,
        ]);

        final stdoutOutput = await process.stdoutStream().join('\n');
        await process.shouldExit(0);

        expect(stdoutOutput.trim(), equals('Already sorted'));
      },
    );

    test('-w / --overwrite modifies file in place and exits 0', () async {
      await d.file('overwrite_target.dart', unsortedCode).create();
      final filePath = p.join(d.sandbox, 'overwrite_target.dart');

      final process = await TestProcess.start('dart', [
        'run',
        'bin/sort_dart_members.dart',
        '-w',
        filePath,
      ]);

      await process.shouldExit(0);

      final onDisk = File(filePath).readAsStringSync();
      expect(onDisk.trim(), equals(sortedCodeDefault.trim()));
    });

    test(
      '--verbose emits diagnostics to stderr and leaves stdout pure',
      () async {
        await d.file('verbose_test.dart', unsortedCode).create();
        final filePath = p.join(d.sandbox, 'verbose_test.dart');

        final process = await TestProcess.start('dart', [
          'run',
          'bin/sort_dart_members.dart',
          '-v',
          filePath,
        ]);

        final stdoutLines = await process.stdoutStream().join('\n');
        final stderrLines = await process.stderrStream().join('\n');
        await process.shouldExit(0);

        expect(stderrLines, contains('[INFO] Reading file:'));
        expect(stderrLines, contains('[INFO] Sorting complete.'));
        expect(stdoutLines.trim(), equals(sortedCodeDefault.trim()));
        expect(stdoutLines, isNot(contains('[INFO]')));
      },
    );

    test(
      '--sort-constructors-first places constructors before fields',
      () async {
        await d.file('constructors_first.dart', unsortedCode).create();
        final filePath = p.join(d.sandbox, 'constructors_first.dart');

        final process = await TestProcess.start('dart', [
          'run',
          'bin/sort_dart_members.dart',
          '--sort-constructors-first',
          filePath,
        ]);

        final stdoutOutput = await process.stdoutStream().join('\n');
        await process.shouldExit(0);

        expect(stdoutOutput.trim(), equals(sortedCodeConstructorsFirst.trim()));
      },
    );

    test('fails fast on syntax errors with exit code 1', () async {
      const syntaxErrorContent = '''
class Broken {
  void unclosedMethod( {
}
''';
      await d.file('broken.dart', syntaxErrorContent).create();
      final filePath = p.join(d.sandbox, 'broken.dart');

      final process = await TestProcess.start('dart', [
        'run',
        'bin/sort_dart_members.dart',
        filePath,
      ]);

      final stderrOutput = await process.stderrStream().join('\n');
      await process.shouldExit(1);

      expect(stderrOutput, contains('Error sorting members in'));
      expect(File(filePath).readAsStringSync(), equals(syntaxErrorContent));
    });

    test('fails with exit code 1 when file does not exist', () async {
      final nonExistentPath = p.join(d.sandbox, 'non_existent.dart');

      final process = await TestProcess.start('dart', [
        'run',
        'bin/sort_dart_members.dart',
        nonExistentPath,
      ]);

      final stderrOutput = await process.stderrStream().join('\n');
      await process.shouldExit(1);

      expect(stderrOutput, contains('File not found:'));
    });

    test(
      'fails with exit code 64 when file path argument is missing',
      () async {
        final process = await TestProcess.start('dart', [
          'run',
          'bin/sort_dart_members.dart',
        ]);

        final stderrOutput = await process.stderrStream().join('\n');
        await process.shouldExit(64);

        expect(stderrOutput, contains('Missing file path argument.'));
      },
    );

    test(
      'fails with exit code 64 when --check and --overwrite are combined',
      () async {
        await d.file('dummy.dart', 'void main() {}').create();
        final filePath = p.join(d.sandbox, 'dummy.dart');

        final process = await TestProcess.start('dart', [
          'run',
          'bin/sort_dart_members.dart',
          '--check',
          '--overwrite',
          filePath,
        ]);

        final stderrOutput = await process.stderrStream().join('\n');
        await process.shouldExit(64);

        expect(
          stderrOutput,
          contains('Cannot specify both --check and --overwrite.'),
        );
      },
    );

    test('--help prints usage to stdout with exit code 0', () async {
      final process = await TestProcess.start('dart', [
        'run',
        'bin/sort_dart_members.dart',
        '--help',
      ]);

      final stdoutOutput = await process.stdoutStream().join('\n');
      await process.shouldExit(0);

      expect(stdoutOutput, contains('Usage: sort_dart_members'));
      expect(stdoutOutput, contains('--check'));
      expect(stdoutOutput, contains('--overwrite'));
    });

    test('--version prints tool version to stdout with exit code 0', () async {
      final process = await TestProcess.start('dart', [
        'run',
        'bin/sort_dart_members.dart',
        '--version',
      ]);

      final stdoutOutput = await process.stdoutStream().join('\n');
      await process.shouldExit(0);

      expect(stdoutOutput, contains('sort_dart_members version: 0.0.1'));
    });
  });
}
