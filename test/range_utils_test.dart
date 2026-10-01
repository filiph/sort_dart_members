import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';
import 'package:sort_dart_members/src/range_utils.dart';
import 'package:test/test.dart';

void main() {
  group('range_utils nodeWithComments', () {
    test('preserves leading doc comment and inline trailing comment', () {
      const code = '''
class A {
  /// Some documentation
  void foo() {} // inline comment

  void bar() {}
}
''';
      var parseResult = parseString(content: code, throwIfDiagnostics: false);
      var unit = parseResult.unit;
      var lineInfo = parseResult.lineInfo;

      var classDecl = unit.declarations.first as ClassDeclaration;
      var methodFoo = classDecl.body.members.first;

      var nodeRange = range.nodeWithComments(lineInfo, methodFoo);
      var text = code.substring(
        nodeRange.offset,
        nodeRange.offset + nodeRange.length,
      );

      expect(text, contains('/// Some documentation'));
      expect(text, contains('void foo() {} // inline comment'));
      expect(text, isNot(contains('void bar()')));
    });

    test('first node in unit treats leading comments as header', () {
      const code = '''
// Copyright (c) 2026

void firstFunction() {}
void secondFunction() {}
''';
      var parseResult = parseString(content: code, throwIfDiagnostics: false);
      var unit = parseResult.unit;
      var lineInfo = parseResult.lineInfo;

      var firstFunc = unit.declarations.first;
      var firstRange = range.nodeWithComments(lineInfo, firstFunc);
      var firstText = code.substring(
        firstRange.offset,
        firstRange.offset + firstRange.length,
      );

      expect(firstText, equals('void firstFunction() {}'));
      expect(firstText, isNot(contains('Copyright')));

      var secondFunc = unit.declarations[1];
      var secondRange = range.nodeWithComments(lineInfo, secondFunc);
      var secondText = code.substring(
        secondRange.offset,
        secondRange.offset + secondRange.length,
      );
      expect(secondText, equals('void secondFunction() {}'));
    });
  });
}
