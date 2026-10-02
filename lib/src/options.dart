/// Configuration options for the sort operation.
class SortOptions {
  /// The path to the Dart source file to sort.
  final String filePath;

  /// Whether to run in verification mode without modifying files
  /// or emitting sorted code.
  final bool check;

  /// Whether to overwrite the target file in place.
  final bool overwrite;

  /// Whether constructors should be sorted before fields (defaults to false).
  final bool sortConstructorsFirst;

  /// Whether to output verbose diagnostic logs to stderr.
  final bool verbose;

  const SortOptions({
    required this.filePath,
    this.check = false,
    this.overwrite = false,
    this.sortConstructorsFirst = false,
    this.verbose = false,
  });
}

/// The result of running a sort transformation.
final class SortResult {
  /// The original source code before sorting.
  final String originalCode;

  /// The resulting source code after sorting.
  final String sortedCode;

  /// Whether sorting introduced any changes.
  final bool hasChanges;

  const SortResult({required this.originalCode, required this.sortedCode})
    : hasChanges = originalCode != sortedCode;
}
