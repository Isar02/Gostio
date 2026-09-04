import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// What this package is allowed to be. It holds the contract, the session it is
// made under and the brand, and it draws none of it: a widget measured for one
// client is the part that belongs to that client.
void main() {
  final List<File> sources = _sources();

  test('the package has source to check at all', () {
    expect(sources.length, greaterThan(40));
  });

  test('nothing in the package draws', () {
    for (final File source in sources) {
      for (final String line in source.readAsLinesSync()) {
        final RegExpMatch? imported = _import.firstMatch(line);
        if (imported == null) {
          continue;
        }

        expect(
          _drawing.contains(imported.group(1)),
          isFalse,
          reason: '${_named(source)} reaches ${imported.group(1)}',
        );
      }
    }
  });

  // A library nothing exports is one neither client can reach, which is a
  // second copy waiting to be written. A generated file is a part of the
  // library it belongs to rather than a library, so it is not one of these.
  test('every public library the package holds is one it publishes', () {
    final Set<String> published = File('lib/gostio_core.dart')
        .readAsLinesSync()
        .map(_export.firstMatch)
        .nonNulls
        .map((RegExpMatch matched) => matched.group(1)!)
        .toSet();

    for (final File source in sources) {
      expect(
        published,
        contains(_named(source)),
        reason: '${_named(source)} is not exported',
      );
    }
  });
}

const Set<String> _drawing = <String>{
  'package:flutter/material.dart',
  'package:flutter/widgets.dart',
  'package:flutter/cupertino.dart',
};

final RegExp _import = RegExp(r"""^\s*import\s+['"]([^'"]+)['"]""");

final RegExp _export = RegExp(r"""^\s*export\s+['"]([^'"]+)['"]""");

String _named(File source) =>
    source.path.replaceAll(r'\', '/').split('lib/').last;

List<File> _sources() =>
    Directory('lib/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .where((File file) => !file.path.endsWith('.g.dart'))
        .toList(growable: false);
