import 'src/member_sorter.dart';
import 'src/options.dart';

export 'src/directive_sorter.dart' show DirectiveSorter;
export 'src/member_sorter.dart'
    show MemberSorter, MemberSortException, SimpleDiff, computeSimpleDiff;
export 'src/options.dart' show SortOptions, SortResult;
export 'src/range_utils.dart' show RangeUtilsExtension;

/// Sorts the members and directives of the provided Dart source [code].
///
/// If [sortConstructorsFirst] is `true`, constructors are sorted before fields;
/// otherwise, constructors are sorted after fields (the default).
///
/// Throws [MemberSortException] if [code] contains syntax errors.
SortResult sortDartMembers(String code, {bool sortConstructorsFirst = false}) {
  return MemberSorter.fromCode(
    code,
    sortConstructorsFirst: sortConstructorsFirst,
  ).sort();
}
