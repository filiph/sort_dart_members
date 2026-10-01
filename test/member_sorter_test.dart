import 'package:sort_dart_members/sort_dart_members.dart';
import 'package:test/test.dart';

void main() {
  group('MemberSorter', () {
    test('sorts class members with constructors after fields by default', () {
      const code = '''
class Example {
  void zMethod() {}

  Example();

  int aField = 1;

  static int sField = 2;

  void aMethod() {}
}
''';
      final result = sortDartMembers(code);
      const expected = '''
class Example {
  static int sField = 2;

  int aField = 1;

  Example();

  void aMethod() {}

  void zMethod() {}
}
''';
      expect(result.sortedCode, equals(expected));
      expect(result.hasChanges, isTrue);
    });

    test('sorts class members with constructors before fields when sortConstructorsFirst is true', () {
      const code = '''
class Example {
  int aField = 1;

  Example();

  static int sField = 2;

  void aMethod() {}
}
''';
      final result = sortDartMembers(code, sortConstructorsFirst: true);
      const expected = '''
class Example {
  Example();

  static int sField = 2;

  int aField = 1;

  void aMethod() {}
}
''';
      expect(result.sortedCode, equals(expected));
      expect(result.hasChanges, isTrue);
    });

    test('preserves relative order of multiple fields or fields in same declaration', () {
      const code = '''
class Example {
  int b = 2;
  int a = 1;
}
''';
      // In SDK sorting, class fields are not reordered among themselves!
      final result = sortDartMembers(code);
      expect(result.sortedCode, equals(code));
      expect(result.hasChanges, isFalse);
    });

    test('sorts getters, setters, and methods alphabetically', () {
      const code = '''
class Accessors {
  set b(int val) {}
  int get b => 0;
  set a(int val) {}
  int get a => 0;
}
''';
      final result = sortDartMembers(code);
      const expected = '''
class Accessors {
  int get a => 0;
  set a(int val) {}
  int get b => 0;
  set b(int val) {}
}
''';
      expect(result.sortedCode, equals(expected));
    });

    test('sorts mixin, enum, extension, and extension type members', () {
      const code = '''
mixin M {
  void z() {}
  void a() {}
}

enum E {
  one, two;

  void z() {}
  void a() {}
}

extension Ext on int {
  void z() {}
  void a() {}
}

extension type ET(int i) {
  void z() {}
  void a() {}
}
''';
      final result = sortDartMembers(code);
      const expected = '''
enum E {
  one, two;

  void a() {}
  void z() {}
}

mixin M {
  void a() {}
  void z() {}
}

extension type ET(int i) {
  void a() {}
  void z() {}
}

extension Ext on int {
  void a() {}
  void z() {}
}
''';
      expect(result.sortedCode, equals(expected));
    });

    test('sorts top-level compilation unit declarations', () {
      const code = '''
class B {}
class A {}
void zFunc() {}
const topConst = 1;
void main() {}
int topVar = 2;
''';
      final result = sortDartMembers(code);
      const expected = '''
void main() {}
const topConst = 1;
int topVar = 2;
void zFunc() {}
class A {}
class B {}
''';
      expect(result.sortedCode, equals(expected));
    });

    test('sorts both directives and members', () {
      const code = '''
import 'package:b/b.dart';
import 'dart:io';

class Foo {
  void b() {}
  void a() {}
}
''';
      final result = sortDartMembers(code);
      const expected = '''
import 'dart:io';

import 'package:b/b.dart';

class Foo {
  void a() {}
  void b() {}
}
''';
      expect(result.sortedCode, equals(expected));
    });

    test('throws MemberSortException on syntax errors', () {
      const code = '''
class Broken {
  void invalid( {
}
''';
      expect(() => sortDartMembers(code), throwsA(isA<MemberSortException>()));
    });

    test('handles already sorted files without changes', () {
      const code = '''
import 'dart:io';

class A {
  int x = 1;

  void foo() {}
}
''';
      final result = sortDartMembers(code);
      expect(result.hasChanges, isFalse);
      expect(result.sortedCode, equals(code));
    });
  });
}
