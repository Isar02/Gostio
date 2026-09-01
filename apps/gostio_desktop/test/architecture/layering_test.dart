import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The directions a dependency in this client is allowed to point.
void main() {
  final List<_Source> sources = _lib();

  test('the client has source to check at all', () {
    expect(sources.length, greaterThan(50));
  });

  test('core reaches neither a feature nor the application', () {
    for (final _Source source in sources.where(
      (_Source source) => source.path.startsWith('core/'),
    )) {
      for (final String imported in source.reaches) {
        expect(
          imported.startsWith('features/') || imported.startsWith('app/'),
          isFalse,
          reason: '${source.path} reaches back to $imported',
        );
      }
    }
  });

  // The application composes the features; a feature that knew the shell would
  // close the circle and could not be read on its own.
  test('a feature never reaches the application', () {
    for (final _Source source in sources.where(
      (_Source source) => source.path.startsWith('features/'),
    )) {
      for (final String imported in source.reaches) {
        expect(
          imported.startsWith('app/'),
          isFalse,
          reason: '${source.path} reaches back to $imported',
        );
      }
    }
  });

  test('a data layer never reaches a presentation layer', () {
    for (final _Source source in sources.where(
      (_Source source) => source.path.contains('/data/'),
    )) {
      for (final String imported in source.reaches) {
        expect(
          imported.contains('/presentation/'),
          isFalse,
          reason: '${source.path} reaches $imported',
        );
      }
    }
  });

  // A feature composes the widgets the two shared features publish — the
  // photographs and status of any listing, the city a form picks — and reaches
  // nothing else another feature draws.
  test('a feature reaches only a shared feature for what it draws', () {
    for (final _Source source in sources) {
      final String? feature = _featureOf(source.path);
      if (feature == null) {
        continue;
      }

      for (final String imported in source.reaches) {
        final String? other = _featureOf(imported);
        if (other == null ||
            other == feature ||
            !imported.contains('/presentation/')) {
          continue;
        }

        expect(
          _shared.contains(other),
          isTrue,
          reason: '${source.path} reaches $imported, which is $other drawing',
        );
      }
    }
  });
}

// The features another feature may compose from.
const Set<String> _shared = <String>{'listings', 'reference'};

String? _featureOf(String path) {
  if (!path.startsWith('features/')) {
    return null;
  }

  final List<String> parts = path.split('/');

  return parts.length > 1 ? parts[1] : null;
}

List<_Source> _lib() {
  final Directory lib = Directory('lib');

  return lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((File file) => file.path.endsWith('.dart'))
      .map((File file) => _Source.read(file))
      .toList(growable: false);
}

class _Source {
  _Source(this.path, this.reaches);

  factory _Source.read(File file) {
    final String path = _asPosix(file.path).split('lib/').last;

    // An export carries the same dependency an import does, so both are read.
    final List<String> reaches = <String>[];

    for (final String line in file.readAsLinesSync()) {
      final RegExpMatch? matched = _directive.firstMatch(line);
      if (matched == null) {
        continue;
      }

      final String target = matched.group(1)!;
      if (target.startsWith('package:gostio_desktop/')) {
        reaches.add(target.split('gostio_desktop/').last);
      } else if (!target.startsWith('package:') &&
          !target.startsWith('dart:')) {
        reaches.add(_resolved(path, target));
      }
    }

    return _Source(path, reaches);
  }

  final String path;
  final List<String> reaches;

  static final RegExp _directive = RegExp(
    r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""",
  );

  static String _asPosix(String path) => path.replaceAll(r'\', '/');

  // A relative import is read against the folder it was written in, so both
  // forms end up as one path under lib and are compared like with like.
  static String _resolved(String from, String target) {
    final List<String> parts = from.split('/')..removeLast();

    for (final String step in target.split('/')) {
      if (step == '..') {
        if (parts.isNotEmpty) {
          parts.removeLast();
        }
      } else if (step != '.') {
        parts.add(step);
      }
    }

    return parts.join('/');
  }
}
