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
