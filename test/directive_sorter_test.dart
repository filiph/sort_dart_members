import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:sort_dart_members/src/directive_sorter.dart';
import 'package:test/test.dart';

void main() {
  group('DirectiveSorter', () {
    test(
      'sorts dart:, package:, and relative imports with blank line grouping',
      () {
        const code = '''
import 'package:path/path.dart';
import 'dart:io';
import './local.dart';
import 'dart:async';

void main() {}
''';
        var parseResult = parseString(content: code, throwIfDiagnostics: false);
        var sorter = DirectiveSorter(code, parseResult.unit);
        var result = sorter.sort();

        const expected = '''
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';

import './local.dart';

void main() {}
''';
        expect(result, equals(expected));
      },
    );

    test('preserves trailing comments on imports', () {
      const code = '''
import 'package:b/b.dart'; // import b
import 'package:a/a.dart'; // import a

void main() {}
''';
      var parseResult = parseString(content: code, throwIfDiagnostics: false);
      var sorter = DirectiveSorter(code, parseResult.unit);
      var result = sorter.sort();

      const expected = '''
import 'package:a/a.dart'; // import a
import 'package:b/b.dart'; // import b

void main() {}
''';
      expect(result, equals(expected));
    });

    test('preserves file doc comments on pseudo-library directive', () {
      const code = '''
/// Library documentation comment.

import 'package:b/b.dart';
import 'package:a/a.dart';

void main() {}
''';
      var parseResult = parseString(content: code, throwIfDiagnostics: false);
      var sorter = DirectiveSorter(code, parseResult.unit);
      var result = sorter.sort();

      const expected = '''
/// Library documentation comment.

import 'package:a/a.dart';
import 'package:b/b.dart';

void main() {}
''';
      expect(result, equals(expected));
    });

    test('sorts imports, exports, and parts in proper priority', () {
      const code = '''
part 'part_b.dart';
part 'part_a.dart';
export 'package:foo/foo.dart';
import 'package:bar/bar.dart';
import 'dart:io';
''';
      var parseResult = parseString(content: code, throwIfDiagnostics: false);
      var sorter = DirectiveSorter(code, parseResult.unit);
      var result = sorter.sort();

      const expected = '''
import 'dart:io';

import 'package:bar/bar.dart';

export 'package:foo/foo.dart';

part 'part_a.dart';
part 'part_b.dart';
''';
      expect(result, equals(expected));
    });

    test('preserves CRLF line endings', () {
      const code =
          "import 'package:b/b.dart';\r\nimport 'dart:io';\r\n\r\nvoid main() {}\r\n";
      var parseResult = parseString(content: code, throwIfDiagnostics: false);
      var sorter = DirectiveSorter(code, parseResult.unit);
      var result = sorter.sort();

      const expected =
          "import 'dart:io';\r\n\r\nimport 'package:b/b.dart';\r\n\r\nvoid main() {}\r\n";
      expect(result, equals(expected));
    });
  });
}
