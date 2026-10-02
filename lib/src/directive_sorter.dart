import 'dart:math' as math;

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/doc_comment.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';

/// Compares two URI strings for a directive to produce the desired sort order.
int _compareDirectiveUri(String a, String b) {
  if (!a.startsWith('package:') || !b.startsWith('package:')) {
    if (!a.startsWith('/') && !b.startsWith('/')) {
      return a.compareTo(b);
    }
  }
  var indexA = a.indexOf('/');
  var indexB = b.indexOf('/');
  if (indexA == -1 || indexB == -1) return a.compareTo(b);
  var result = a.substring(0, indexA).compareTo(b.substring(0, indexB));
  if (result != 0) return result;
  return a.substring(indexA + 1).compareTo(b.substring(indexB + 1));
}

String _docCommentLinePrefix(String lineText) {
  var match = RegExp(r'^\s*(?:///|\*)\s?').firstMatch(lineText);
  return match?.group(0) ?? '/// ';
}

List<_DocCommentLine> _docCommentLines(Comment docComment, String code) {
  var tokens = docComment.tokens;
  if (tokens.length == 1 && !tokens.single.lexeme.startsWith('///')) {
    var token = tokens.single;
    var lines = <_DocCommentLine>[];
    var lineStart = token.offset;
    for (var i = token.offset; i < token.end; i++) {
      if (code.codeUnitAt(i) == 0x0A) {
        var lineEnd = i;
        if (lineEnd > lineStart && code.codeUnitAt(lineEnd - 1) == 0x0D) {
          lineEnd--;
        }
        lines.add(_DocCommentLine(lineStart, lineEnd));
        lineStart = i + 1;
      }
    }
    lines.add(_DocCommentLine(lineStart, token.end));
    return lines;
  }
  return [for (var token in tokens) _DocCommentLine(token.offset, token.end)];
}

bool _isBlankCommentLine(String text) {
  var trimmed = text.trim();
  return trimmed == '///' || trimmed == '*';
}

Map<_DocCommentLine, DocImport> _mapDocImportsToLines(
  Comment docComment,
  String code,
) {
  var docImports = docComment.docImports;
  var docImportByLine = <_DocCommentLine, DocImport>{};
  var docImportIndex = 0;
  for (var line in _docCommentLines(docComment, code)) {
    if (docImportIndex >= docImports.length) {
      break;
    }
    var docImport = docImports[docImportIndex];
    if (docImport.offset >= line.offset && docImport.offset < line.end) {
      docImportByLine[line] = docImport;
      docImportIndex++;
    }
  }
  return docImportByLine;
}

/// Organizes and sorts directives at the compilation unit level.
class DirectiveSorter {
  /// The original code.
  final String initialCode;

  /// The compilation unit of the original code.
  final CompilationUnit unit;

  String _code;

  late final String _endOfLine;

  /// Instantiates a new instance of [DirectiveSorter].
  DirectiveSorter(this.initialCode, this.unit) : _code = initialCode {
    _endOfLine = getEOL(_code);
  }

  /// Sorts all directives (library, imports, exports, parts) and doc imports.
  String sort() {
    _organizeDirectives();
    return _code;
  }

  /// Organize all [Directive]s.
  void _organizeDirectives() {
    var lineInfo = unit.lineInfo;
    LibraryDirective? libraryDirective;
    var directives = <_DirectiveInfo>[];

    for (var directive in unit.directives) {
      if (directive is LibraryDirective) {
        libraryDirective = directive;
      }
      if (directive is UriBasedDirective) {
        int? libraryDocsAndAnnotationsEndOffset;
        var uriContent = directive.uri.stringValue ?? '';
        var priority = switch (directive) {
          ImportDirective() => _DirectiveSortPriority(
            uriContent,
            _DirectiveSortKind.import,
          ),
          ExportDirective() => _DirectiveSortPriority(
            uriContent,
            _DirectiveSortKind.export,
          ),
          PartDirective() => _DirectiveSortPriority(
            uriContent,
            _DirectiveSortKind.part,
          ),
        };

        var offset = directive.offset;
        var end = directive.end;

        var isPseudoLibraryDirective =
            (libraryDirective == null) && directive == unit.directives.first;
        Annotation? lastLibraryAnnotation;
        if (isPseudoLibraryDirective) {
          lastLibraryAnnotation = directive.metadata
              .takeWhile(_isLibraryTargetAnnotation)
              .lastOrNull;

          libraryDocsAndAnnotationsEndOffset =
              lastLibraryAnnotation?.end ?? directive.documentationComment?.end;

          if (libraryDocsAndAnnotationsEndOffset != null) {
            libraryDocsAndAnnotationsEndOffset = lineInfo.getOffsetOfLineAfter(
              libraryDocsAndAnnotationsEndOffset,
            );
            var nextLineOffset = lineInfo.getOffsetOfLineAfter(
              libraryDocsAndAnnotationsEndOffset,
            );
            if (_code
                .substring(libraryDocsAndAnnotationsEndOffset, nextLineOffset)
                .trim()
                .isEmpty) {
              libraryDocsAndAnnotationsEndOffset = nextLineOffset;
            }
          }
        }

        var leadingToken = lastLibraryAnnotation == null
            ? directive.beginToken
            : null;
        var leadingComment = leadingToken != null
            ? getLeadingComment(
                unit,
                leadingToken,
                lineInfo,
                isPseudoLibraryDirective: isPseudoLibraryDirective,
              )
            : null;
        var trailingComment = getTrailingComment(unit, directive, lineInfo);

        if (leadingComment != null && leadingToken != null) {
          offset = libraryDocsAndAnnotationsEndOffset != null
              ? math.max(
                  libraryDocsAndAnnotationsEndOffset,
                  leadingComment.offset,
                )
              : leadingComment.offset;
        }
        if (trailingComment != null) {
          end = trailingComment.end;
        }
        offset = libraryDocsAndAnnotationsEndOffset ?? offset;
        var text = _code.substring(offset, end);
        directives.add(
          _DirectiveInfo(directive, priority, uriContent, offset, end, text),
        );
      }
    }

    _organizeDocImports(libraryDirective);

    if (directives.isEmpty) {
      return;
    }

    var firstDirectiveOffset = directives.first.offset;
    var lastDirectiveEnd = directives.last.end;

    // Sort directives according to priority and URI.
    directives.sort();

    // Append directives with grouping.
    String directivesCode;
    {
      var sb = StringBuffer();
      _DirectiveSortPriority? currentPriority;
      for (var directiveInfo in directives) {
        if (currentPriority != directiveInfo.priority) {
          if (currentPriority != null) {
            sb.write(_endOfLine);
          }
          currentPriority = directiveInfo.priority;
        }
        sb.write(directiveInfo.text);
        sb.write(_endOfLine);
      }
      directivesCode = sb.toString().trimRight();
    }

    var beforeDirectives = _code.substring(0, firstDirectiveOffset);
    var afterDirectives = _code.substring(lastDirectiveEnd);
    _code = beforeDirectives + directivesCode + afterDirectives;
  }

  /// Sorts the `@docImport` directives in the documentation comment of
  /// [libraryDirective], if any.
  void _organizeDocImports(LibraryDirective? libraryDirective) {
    var docComment = libraryDirective?.documentationComment;
    if (docComment == null) {
      return;
    }
    var docImports = docComment.docImports;
    if (docImports.isEmpty) {
      return;
    }

    var lines = _docCommentLines(docComment, _code);
    var docImportByLine = _mapDocImportsToLines(docComment, _code);

    var isBlockComment =
        docComment.tokens.length == 1 &&
        !docComment.tokens.single.lexeme.startsWith('///');
    if (isBlockComment) {
      _organizeDocImportsInBlockComment(docComment, lines, docImportByLine);
      return;
    }

    var sortedInfos = [
      for (var entry in docImportByLine.entries)
        _DocImportInfo(
          entry.value,
          _code.substring(entry.key.offset, entry.key.end),
        ),
    ]..sort();

    var blankLine = _docCommentLinePrefix(sortedInfos.first.text).trimRight();
    var sortedTexts = <String>[];
    _DirectiveSortPriority? previousPriority;
    for (var info in sortedInfos) {
      if (previousPriority != null && previousPriority != info.priority) {
        sortedTexts.add(blankLine);
      }
      sortedTexts.add(info.text);
      previousPriority = info.priority;
    }

    var firstDocImportIndex = lines.indexWhere(docImportByLine.containsKey);
    var lastDocImportIndex = lines.lastIndexWhere(docImportByLine.containsKey);

    bool isBlankLineBetweenDocImports(int index) =>
        index > firstDocImportIndex &&
        index < lastDocImportIndex &&
        _isBlankCommentLine(
          _code.substring(lines[index].offset, lines[index].end),
        );

    var newLines = [
      for (var i = 0; i < firstDocImportIndex; i++)
        _code.substring(lines[i].offset, lines[i].end),
      ...sortedTexts,
      for (var i = lastDocImportIndex + 1; i < lines.length; i++)
        if (!isBlankLineBetweenDocImports(i))
          _code.substring(lines[i].offset, lines[i].end),
    ];

    _code =
        _code.substring(0, docComment.offset) +
        newLines.join(_endOfLine) +
        _code.substring(docComment.end);
  }

  void _organizeDocImportsInBlockComment(
    Comment docComment,
    List<_DocCommentLine> lines,
    Map<_DocCommentLine, DocImport> docImportByLine,
  ) {
    String rawContent(_DocCommentLine line) {
      var lineText = _code.substring(line.offset, line.end);
      var match = RegExp(r'^\s*(?:\*|/\*\*)\s?(.*?)(\s*\*/)?$')
          .firstMatch(lineText);
      return match?.group(1) ?? lineText;
    }

    var sortedInfos = [
      for (var entry in docImportByLine.entries)
        _DocImportInfo(entry.value, rawContent(entry.key)),
    ]..sort();

    var sortedContents = <String>[];
    _DirectiveSortPriority? previousPriority;
    for (var info in sortedInfos) {
      if (previousPriority != null && previousPriority != info.priority) {
        sortedContents.add('');
      }
      sortedContents.add(info.text);
      previousPriority = info.priority;
    }

    var firstDocImportIndex = lines.indexWhere(docImportByLine.containsKey);
    var lastDocImportIndex = lines.lastIndexWhere(docImportByLine.containsKey);

    bool isBlankLineBetweenDocImports(int index) =>
        index > firstDocImportIndex &&
        index < lastDocImportIndex &&
        _isBlankCommentLine(
          _code.substring(lines[index].offset, lines[index].end),
        );

    var otherContents = [
      for (var i = 0; i < lines.length; i++)
        if (!docImportByLine.containsKey(lines[i]) &&
            !isBlankLineBetweenDocImports(i) &&
            !(lines[i] == lines.last && rawContent(lines[i]).isEmpty))
          rawContent(lines[i]),
    ];
    var otherContentsBeforeFirstDocImport = lines
        .take(firstDocImportIndex)
        .where((line) => !docImportByLine.containsKey(line))
        .length;

    var newContents = [
      ...otherContents.take(otherContentsBeforeFirstDocImport),
      ...sortedContents,
      ...otherContents.skip(otherContentsBeforeFirstDocImport),
    ];

    var newLines = [
      for (var (index, content) in newContents.indexed)
        if (index == 0)
          content.isEmpty ? '/**' : '/** $content'
        else
          content.isEmpty ? ' *' : ' * $content',
      ' */',
    ];

    _code =
        _code.substring(0, docComment.offset) +
        newLines.join(_endOfLine) +
        _code.substring(docComment.end);
  }

  /// Return the EOL to use for [code].
  static String getEOL(String code) {
    if (code.contains('\r\n')) {
      return '\r\n';
    } else {
      return '\n';
    }
  }

  /// Gets the first comment token considered to be the leading comment for this
  /// token.
  static Token? getLeadingComment(
    CompilationUnit unit,
    Token beginToken,
    LineInfo lineInfo, {
    required bool isPseudoLibraryDirective,
  }) {
    if (beginToken.precedingComments == null) {
      return null;
    }

    Token? firstComment = beginToken.precedingComments;
    var comment = firstComment;
    var nextComment = comment?.next;
    while (isPseudoLibraryDirective && comment != null && nextComment != null) {
      if (lineInfo.lineNumberDifference(comment.offset, nextComment.offset) >
          1) {
        firstComment = nextComment;
      }
      comment = nextComment;
      nextComment = comment.next;
    }

    if (firstComment is LanguageVersionToken) {
      firstComment = firstComment.next;
    }

    if (firstComment != null &&
        firstComment == unit.beginToken.precedingComments) {
      return _isIgnoreComment(firstComment) ? firstComment : null;
    }

    comment = firstComment;
    if (isPseudoLibraryDirective && comment != null) {
      if (lineInfo.lineNumberDifference(beginToken.offset, comment.offset) ==
          -1) {
        return comment;
      } else {
        return null;
      }
    }
    while (comment != null &&
        beginToken.previous != null &&
        lineInfo.onSameLine(beginToken.previous!.end, comment.offset)) {
      comment = comment.next;
    }
    return comment;
  }

  /// Gets the last comment token considered to be the trailing comment for this
  /// directive.
  static Token? getTrailingComment(
    CompilationUnit unit,
    UriBasedDirective directive,
    LineInfo lineInfo,
  ) {
    Token? comment = directive.endToken.next?.precedingComments;
    Token? result;
    while (comment != null) {
      if (lineInfo.onSameLine(comment.offset, directive.end)) {
        result = comment;
      }
      comment = comment.next;
    }
    return result;
  }

  static bool _isIgnoreComment(Token token) {
    var text = token.lexeme.trim();
    return text.startsWith('// ignore:') || text.startsWith('//ignore:');
  }

  static bool _isLibraryTargetAnnotation(Annotation annotation) {
    var name = annotation.name.name;
    return name == 'TestOn' || name == 'DefaultAsset';
  }
}

class _DirectiveInfo implements Comparable<_DirectiveInfo> {
  final UriBasedDirective directive;
  final _DirectiveSortPriority priority;
  final String uri;
  final int offset;
  final int end;
  final String text;

  _DirectiveInfo(
    this.directive,
    this.priority,
    this.uri,
    this.offset,
    this.end,
    this.text,
  );

  @override
  int compareTo(_DirectiveInfo other) {
    if (priority == other.priority) {
      var compare = _compareDirectiveUri(uri, other.uri);
      if (compare != 0) {
        return compare;
      }
      return text.compareTo(other.text);
    }
    return priority.ordinal - other.priority.ordinal;
  }

  @override
  String toString() => '(priority=$priority; text=$text)';
}

/// The kind of directive for sorting purposes.
enum _DirectiveSortKind { import, export, part }

/// The priority used for grouping directives when sorting.
class _DirectiveSortPriority {
  static const importSdk = _DirectiveSortPriority._('IMPORT_SDK', 0);
  static const importPkg = _DirectiveSortPriority._('IMPORT_PKG', 1);
  static const importOther = _DirectiveSortPriority._('IMPORT_OTHER', 2);
  static const importRel = _DirectiveSortPriority._('IMPORT_REL', 3);
  static const exportSdk = _DirectiveSortPriority._('EXPORT_SDK', 4);
  static const exportPkg = _DirectiveSortPriority._('EXPORT_PKG', 5);
  static const exportOther = _DirectiveSortPriority._('EXPORT_OTHER', 6);
  static const exportRel = _DirectiveSortPriority._('EXPORT_REL', 7);
  static const part = _DirectiveSortPriority._('PART', 8);

  final String name;
  final int ordinal;

  factory _DirectiveSortPriority(String uri, _DirectiveSortKind kind) {
    switch (kind) {
      case _DirectiveSortKind.import:
        if (uri.startsWith('dart:')) {
          return _DirectiveSortPriority.importSdk;
        } else if (uri.startsWith('package:')) {
          return _DirectiveSortPriority.importPkg;
        } else if (uri.contains('://')) {
          return _DirectiveSortPriority.importOther;
        } else {
          return _DirectiveSortPriority.importRel;
        }
      case _DirectiveSortKind.export:
        if (uri.startsWith('dart:')) {
          return _DirectiveSortPriority.exportSdk;
        } else if (uri.startsWith('package:')) {
          return _DirectiveSortPriority.exportPkg;
        } else if (uri.contains('://')) {
          return _DirectiveSortPriority.exportOther;
        } else {
          return _DirectiveSortPriority.exportRel;
        }
      case _DirectiveSortKind.part:
        return _DirectiveSortPriority.part;
    }
  }

  const _DirectiveSortPriority._(this.name, this.ordinal);

  @override
  String toString() => name;
}

/// A single physical line within a documentation comment.
class _DocCommentLine {
  final int offset;
  final int end;

  const _DocCommentLine(this.offset, this.end);

  @override
  int get hashCode => Object.hash(offset, end);

  @override
  bool operator ==(Object other) =>
      other is _DocCommentLine && other.offset == offset && other.end == end;
}

class _DocImportInfo implements Comparable<_DocImportInfo> {
  final _DirectiveSortPriority priority;
  final String uri;
  final String text;

  _DocImportInfo(DocImport docImport, this.text)
    : uri = docImport.import.uri.stringValue ?? '',
      priority = _DirectiveSortPriority(
        docImport.import.uri.stringValue ?? '',
        _DirectiveSortKind.import,
      );

  @override
  int compareTo(_DocImportInfo other) {
    if (priority == other.priority) {
      var compare = _compareDirectiveUri(uri, other.uri);
      if (compare != 0) {
        return compare;
      }
      return text.compareTo(other.text);
    }
    return priority.ordinal - other.priority.ordinal;
  }
}
