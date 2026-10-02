import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/range_factory.dart';

/// Represents a token that may include an optional following comma.
class TokenWithOptionalComma {
  final Token token;
  final bool includesComma;

  TokenWithOptionalComma(this.token, this.includesComma);
}

/// Extension on [RangeFactory] providing AST node range calculations
/// that properly incorporate leading doc/code comments and trailing
/// inline comments.
extension RangeUtilsExtension on RangeFactory {
  /// Return the left-most comment immediately before the [token] that is not on
  /// the same line as the first non-comment token before the [token]. Return
  /// the [token] if there is no such comment.
  Token leadingComment(LineInfo lineInfo, Token token) {
    var previous = token.previous;
    if (previous == null || previous.isEof) {
      return token.precedingComments ?? token;
    }
    Token? comment = token.precedingComments;
    if (_areDifferentLines(lineInfo, token, previous)) {
      while (comment != null) {
        if (_areDifferentLines(lineInfo, previous, comment)) {
          break;
        }
        comment = comment.next;
      }
    }
    return comment ?? token;
  }

  /// Return a source range that covers the given [node] with any leading and
  /// trailing comments.
  ///
  /// The range begins at the start of any leading comment token (excluding any
  /// token considered a trailing comment for the previous node) or the start
  /// of the node itself if there are none.
  ///
  /// The range ends at the end of the trailing comment token or the end of the
  /// node itself if there is not one.
  SourceRange nodeWithComments(LineInfo lineInfo, AstNode node) {
    var beginToken = node.beginToken;
    // If the node is the first thing in the unit, leading comments are treated
    // as headers and should never be included in the range.
    var isFirstItem = beginToken == node.root.beginToken;

    var thisLeadingComment = isFirstItem
        ? beginToken
        : leadingComment(lineInfo, beginToken);
    var thisTrailingComment = trailingComment(
      lineInfo,
      node.endToken,
      returnComma: false,
    );

    return startEnd(thisLeadingComment, thisTrailingComment.token);
  }

  /// Return the trailing comment token following the [token] if it is on the
  /// same line as the [token], or return the [token] if there is no trailing
  /// comment or if the comment is on a different line than the [token].
  TokenWithOptionalComma trailingComment(
    LineInfo lineInfo,
    Token token, {
    required bool returnComma,
  }) {
    var lastToken = token;
    var nextToken = lastToken.next!;
    var includesComma =
        nextToken.type == TokenType.COMMA &&
        _shouldIncludeCommentsAfterComma(lineInfo, nextToken);
    if (includesComma) {
      lastToken = nextToken;
      nextToken = lastToken.next!;
    }
    Token? comment = nextToken.precedingComments;

    if (comment == null &&
        includesComma &&
        _areDifferentLines(lineInfo, token, lastToken)) {
      comment = lastToken.precedingComments;
      lastToken = token;
    }
    if (comment != null) {
      var currentComment = comment;
      if (lineInfo.onSameLine(currentComment.offset, lastToken.offset)) {
        var next = currentComment.next;
        while (next != null &&
            lineInfo.onSameLine(next.offset, lastToken.offset)) {
          currentComment = next;
          next = next.next;
        }
        return TokenWithOptionalComma(currentComment, includesComma);
      }
    }
    return TokenWithOptionalComma(returnComma ? lastToken : token, false);
  }

  bool _areDifferentLines(LineInfo lineInfo, Token token, Token other) =>
      !lineInfo.onSameLine(token.offset, other.offset);

  bool _shouldIncludeCommentsAfterComma(LineInfo lineInfo, Token comma) {
    var tokenAfterComma = comma.next!;
    var tokenTypeAfterComma = tokenAfterComma.type;
    if (tokenTypeAfterComma == TokenType.CLOSE_CURLY_BRACKET ||
        tokenTypeAfterComma == TokenType.CLOSE_PAREN ||
        tokenTypeAfterComma == TokenType.CLOSE_SQUARE_BRACKET) {
      return true;
    }
    return _areDifferentLines(lineInfo, comma, tokenAfterComma);
  }
}
