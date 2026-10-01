A command line tool for sorting Dart members in a `.dart` file.

Mimics the behavior of the official 'Sort Members in Dart File' IDE helper
provided by the Dart LSP server
([/src/services/correction/sort_members.dart](https://github.com/dart-lang/sdk/blob/main/pkg/analysis_server/lib/src/services/correction/sort_members.dart)) as of October 2026.
There is no guarantee that this tool will always follow the official
behavior, but that is how we started.

**Disclaimer:** Almost all of the code is built by LLMs.
This is both simple enough and uncreative enough that I have no trouble
outsourcing the work to a tool.


## Installation

```shell
dart pub global activate sort_dart_members
```

## Usage

In order to simply check if a file is already sorted:

```sh
sortdart path/to/file.dart --check
```

This only outputs whether or not that file is already sorted,
and also expresses the same result with an exit code (0 = sorted, 1 = not).

If you want to see what the file will look like:

```sh
sortdart path/to/file.dart
```

This will output the sorted file to stdout.

If you want to apply the sorting in place, use `--overwrite` (`-w`):

```sh
sortdart --overwrite path/to/file.dart
```

