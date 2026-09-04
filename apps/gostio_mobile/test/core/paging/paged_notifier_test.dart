import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/paging/paged_notifier.dart';

void main() {
  late _Catalogue catalogue;

  setUp(() => catalogue = _Catalogue('Mostar'));

  tearDown(() => catalogue.dispose());

  test(
    'a first page is what the list holds and how much of the whole',
    () async {
      final Future<void> reading = catalogue.apply('Mostar');
      catalogue.answer(_page(1, <String>['Old town loft'], total: 43));
      await reading;

      expect(catalogue.items, <String>['Old town loft']);
      expect(catalogue.totalCount, 43);
      expect(catalogue.hasMore, isTrue);
    },
  );

  // A thumb has no footer to move through pages with, so the next page joins
  // the one before it rather than replacing it.
  test('the next page is added to what is already read', () async {
    await _fill(catalogue, <String>['Old town loft'], total: 43);

    final Future<void> reading = catalogue.more();
    catalogue.answer(_page(2, <String>['Stone villa above Neum'], total: 43));
    await reading;

    expect(catalogue.items, <String>[
      'Old town loft',
      'Stone villa above Neum',
    ]);
    expect(catalogue.page, 2);
  });

  test('a filter replaces the list rather than growing it', () async {
    await _fill(catalogue, <String>['Old town loft'], total: 43);

    final Future<void> reading = catalogue.apply('Neum');
    catalogue.answer(_page(1, <String>['Stone villa above Neum'], total: 2));
    await reading;

    expect(catalogue.items, <String>['Stone villa above Neum']);
    expect(catalogue.query, 'Neum');
    expect(catalogue.totalCount, 2);
  });

  test('a list that holds everything asks for no more', () async {
    await _fill(catalogue, <String>['Old town loft'], total: 1);

    expect(catalogue.hasMore, isFalse);

    await catalogue.more();

    expect(catalogue.reads, 1);
  });

  // The list stays on the screen while the next page is fetched, so the two
  // waits are not the same wait.
  test('adding a page is not the wait that has nothing to show', () async {
    await _fill(catalogue, <String>['Old town loft'], total: 43);

    final Future<void> reading = catalogue.more();

    expect(catalogue.isAppending, isTrue);
    expect(catalogue.isLoading, isFalse);

    catalogue.answer(
      _page(2, <String>['Cottage by the Pliva lakes'], total: 43),
    );
    await reading;

    expect(catalogue.isAppending, isFalse);
  });

  // A slow first page landing on top of the filtered list that replaced it is
  // the bug this guards.
  test('a request that was overtaken writes nothing', () async {
    final Future<void> first = catalogue.apply('Mostar');
    final Future<void> second = catalogue.apply('Neum');

    catalogue.answerAt(
      1,
      _page(1, <String>['Stone villa above Neum'], total: 2),
    );
    await second;

    catalogue.answerAt(0, _page(1, <String>['Old town loft'], total: 43));
    await first;

    expect(catalogue.items, <String>['Stone villa above Neum']);
    expect(catalogue.totalCount, 2);
    expect(catalogue.query, 'Neum');
  });

  test('a first page that was refused shows nothing and says why', () async {
    final Future<void> reading = catalogue.apply('Mostar');
    catalogue.refuse(
      ApiException(message: 'The search could not be read.', statusCode: 500),
    );
    await reading;

    expect(catalogue.items, isEmpty);
    expect(catalogue.failureMessage, 'The search could not be read.');
    expect(catalogue.isLoading, isFalse);
  });

  // What was already read is still true, so a page that failed to arrive may
  // not take it off the screen.
  test('a page that was refused leaves what is already read alone', () async {
    await _fill(catalogue, <String>['Old town loft'], total: 43);

    final Future<void> reading = catalogue.more();
    catalogue.refuse(
      ApiException(message: 'That page could not be read.', statusCode: 500),
    );
    await reading;

    expect(catalogue.items, <String>['Old town loft']);
    expect(catalogue.failureMessage, 'That page could not be read.');
    expect(catalogue.hasMore, isTrue);
  });

  // A filter that was refused is still the filter the reader chose, so
  // another go retries it rather than the one it replaced.
  test('another go after a refused filter retries the new one', () async {
    await _fill(catalogue, <String>['Old town loft'], total: 43);

    final Future<void> filtering = catalogue.apply('Neum');
    catalogue.refuse(
      ApiException(message: 'The search could not be read.', statusCode: 500),
    );
    await filtering;

    expect(catalogue.query, 'Neum');

    final Future<void> again = catalogue.retry();

    expect(catalogue.queries.last, 'Neum');

    catalogue.answer(_page(1, <String>['Stone villa above Neum'], total: 2));
    await again;

    expect(catalogue.items, <String>['Stone villa above Neum']);
  });

  // A filter that failed left the list showing the filter before it. Asking
  // for page two of the new query would hand the reader one list built out of
  // two, so another go repeats the read that was refused.
  test('another go after a refused filter reads that filter again', () async {
    await _fill(catalogue, <String>['Old town loft'], total: 43);

    final Future<void> filtering = catalogue.apply('Neum');
    catalogue.refuse(
      ApiException(message: 'The search could not be read.', statusCode: 500),
    );
    await filtering;

    final Future<void> again = catalogue.retry();
    catalogue.answer(_page(1, <String>['Stone villa above Neum'], total: 2));
    await again;

    expect(catalogue.items, <String>['Stone villa above Neum']);
    expect(catalogue.totalCount, 2);
  });

  test('another go after a refused page asks for that page again', () async {
    await _fill(catalogue, <String>['Old town loft'], total: 43);

    final Future<void> adding = catalogue.more();
    catalogue.refuse(
      ApiException(message: 'That page could not be read.', statusCode: 500),
    );
    await adding;

    final Future<void> again = catalogue.retry();
    catalogue.answer(
      _page(2, <String>['Cottage by the Pliva lakes'], total: 43),
    );
    await again;

    expect(catalogue.items, <String>[
      'Old town loft',
      'Cottage by the Pliva lakes',
    ]);
  });

  test('nothing is read again when nothing was refused', () async {
    await _fill(catalogue, <String>['Old town loft'], total: 43);

    await catalogue.retry();

    expect(catalogue.reads, 1);
  });

  test('a page that answers with nothing ends the list', () async {
    await _fill(catalogue, <String>['Old town loft'], total: 43);

    final Future<void> reading = catalogue.more();
    catalogue.answer(_page(2, <String>[], total: 1));
    await reading;

    expect(catalogue.items, <String>['Old town loft']);
    expect(catalogue.hasMore, isFalse);
  });

  test('nothing is asked for before the first page has landed', () async {
    await catalogue.more();

    expect(catalogue.reads, 0);
  });
}

Future<void> _fill(
  _Catalogue catalogue,
  List<String> items, {
  required int total,
}) async {
  final Future<void> reading = catalogue.apply(catalogue.query);
  catalogue.answer(_page(1, items, total: total));

  return reading;
}

PagedResult<String> _page(int page, List<String> items, {required int total}) =>
    PagedResult<String>(
      items: items,
      page: page,
      pageSize: PagedResult.defaultPageSize,
      totalCount: total,
    );

// A list whose pages arrive when a test says so, and in whichever order it
// says, which is what lets one overtake another.
class _Catalogue extends PagedNotifier<String, String> {
  _Catalogue(super.query);

  final List<Completer<PagedResult<String>>> _pending =
      <Completer<PagedResult<String>>>[];

  final List<String> queries = <String>[];

  int get reads => _pending.length;

  void answer(PagedResult<String> result) =>
      answerAt(_pending.length - 1, result);

  void answerAt(int read, PagedResult<String> result) =>
      _pending[read].complete(result);

  void refuse(ApiException failure) => _pending.last.completeError(failure);

  @override
  Future<PagedResult<String>> fetch({
    required int page,
    required String query,
  }) {
    queries.add(query);
    final Completer<PagedResult<String>> answer =
        Completer<PagedResult<String>>();
    _pending.add(answer);

    return answer.future;
  }
}
