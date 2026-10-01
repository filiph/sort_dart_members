import 'dart:io';

import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:sort_dart_members/sort_dart_members.dart';

void main(List<String> arguments) {
  final argParser = buildParser();

  try {
    final results = argParser.parse(arguments);

    if (results.flag('help')) {
      printUsage(argParser, toStderr: false);
      exit(0);
    }

    if (results.flag('version')) {
      stdout.writeln('sort_dart_members version: $version');
      exit(0);
    }

    final verbose = results.flag('verbose');
    Logger.root.level = verbose ? Level.ALL : Level.OFF;
    Logger.root.onRecord.listen((record) {
      stderr.writeln('[${record.level.name}] ${record.message}');
    });

    final log = Logger('sort_dart_members');

    final check = results.flag('check');
    final overwrite = results.flag('overwrite');
    final sortConstructorsFirst = results.flag('sort-constructors-first');

    if (check && overwrite) {
      stderr.writeln('Error: Cannot specify both --check and --overwrite.');
      stderr.writeln('');
      printUsage(argParser, toStderr: true);
      exit(64);
    }

    if (results.rest.isEmpty) {
      stderr.writeln('Error: Missing file path argument.');
      stderr.writeln('');
      printUsage(argParser, toStderr: true);
      exit(64);
    }

    if (results.rest.length > 1) {
      stderr.writeln(
        'Error: Expected a single file path argument, but got: ${results.rest.join(' ')}',
      );
      stderr.writeln('');
      printUsage(argParser, toStderr: true);
      exit(64);
    }

    final filePath = results.rest.first;
    final file = File(filePath);

    if (!file.existsSync()) {
      stderr.writeln('Error: File not found: $filePath');
      exit(1);
    }

    log.info('Reading file: $filePath');
    final String content;
    try {
      content = file.readAsStringSync();
    } catch (e) {
      stderr.writeln('Error reading file $filePath: $e');
      exit(1);
    }

    log.info(
      'Sorting members (sortConstructorsFirst: $sortConstructorsFirst)...',
    );
    final SortResult sortResult;
    try {
      sortResult = sortDartMembers(
        content,
        sortConstructorsFirst: sortConstructorsFirst,
      );
    } on MemberSortException catch (e) {
      stderr.writeln('Error sorting members in $filePath:');
      stderr.writeln(e.message);
      exit(1);
    } catch (e, stackTrace) {
      stderr.writeln('Fatal error sorting members in $filePath: $e');
      log.fine('Stack trace: $stackTrace');
      exit(1);
    }

    log.info('Sorting complete. Has changes: ${sortResult.hasChanges}');

    if (check) {
      if (sortResult.hasChanges) {
        stderr.writeln('File is not sorted');
        exit(1);
      } else {
        stdout.writeln('Already sorted');
        exit(0);
      }
    }

    if (overwrite) {
      if (sortResult.hasChanges) {
        log.info('Writing sorted content back to $filePath');
        file.writeAsStringSync(sortResult.sortedCode);
      } else {
        log.info('File is already sorted; no write required.');
      }
      exit(0);
    }

    // Default mode: emit sorted code to stdout.
    stdout.write(sortResult.sortedCode);
    exit(0);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln('');
    printUsage(argParser, toStderr: true);
    exit(64);
  }
}

/// If you change this, also change the version in pubspec.yaml.
const String version = '0.1.1';

ArgParser buildParser() {
  return ArgParser()
    ..addFlag(
      'check',
      negatable: false,
      help: 'Check if the file is already sorted without modifying it.',
    )
    ..addFlag(
      'overwrite',
      abbr: 'w',
      negatable: false,
      help: 'Overwrite the file with sorted contents.',
    )
    ..addFlag(
      'sort-constructors-first',
      defaultsTo: false,
      negatable: true,
      help: 'Sort constructors before fields (defaults to false).',
    )
    ..addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'Show verbose diagnostic logging on stderr.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Print this usage information.',
    )
    ..addFlag('version', negatable: false, help: 'Print the tool version.');
}

void printUsage(ArgParser argParser, {bool toStderr = true}) {
  final out = toStderr ? stderr : stdout;
  out.writeln('Usage: sortdart [options] <file-path>');
  out.writeln('');
  out.writeln('Options:');
  out.writeln(argParser.usage);
}
