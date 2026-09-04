import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../state/live_notifier.dart';

// The state behind a phone list. The desktop replaces a page with the next
// one because it has a footer to move through them with; a thumb has no such
// footer, so here a page is added to what is already read and the reader is
// told how much of the whole they are holding.
//
// This holds a list rather than a request, so it keeps its own state instead
// of a screen's busy-and-failure pair: reading a first page and adding one to
// what is already on screen are two different waits.
//
// Only the newest load may write. A request that is overtaken by a newer one
// leaves nothing behind, so a slow first page cannot land on top of the
// filtered list that replaced it.
abstract class PagedNotifier<T, TQuery> extends LiveNotifier {
  PagedNotifier(this._query);

  int _page = 1;
  int _totalCount = 0;
  int _request = 0;
  bool _isLoading = false;
  bool _isAppending = false;
  bool _hasLanded = false;
  int? _refusedPage;
  TQuery _query;
  ApiException? _failure;
  List<T> _items = List<T>.empty();

  List<T> get items => _items;

  int get page => _page;

  int get pageSize => PagedResult.defaultPageSize;

  int get totalCount => _totalCount;

  // What the reader has asked for, which is not always what the list is
  // showing: a filter that was refused is still the filter in force, and it
  // is the one another go retries.
  TQuery get query => _query;

  // The first read of a query, which is the one with nothing to show behind
  // it. Adding a page is not this: the list stays up while it happens.
  bool get isLoading => _isLoading && !_isAppending;

  bool get isAppending => _isAppending;

  bool get hasLanded => _hasLanded;

  bool get hasMore => _items.length < _totalCount;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  @protected
  Future<PagedResult<T>> fetch({required int page, required TQuery query});

  Future<void> apply(TQuery query) => _load(page: 1, query: query);

  Future<void> reload() => _load(page: 1, query: _query);

  // Another go at the read that was refused, which is not the same as asking
  // for more. A filter that failed left the list showing the results of the
  // filter before it, and fetching page two of the new query onto those would
  // hand the reader one list built out of two.
  Future<void> retry() {
    final int? refused = _refusedPage;

    return refused == null
        ? Future<void>.value()
        : _load(page: refused, query: _query);
  }

  Future<void> more() {
    if (_isLoading || !_hasLanded || !hasMore) {
      return Future<void>.value();
    }

    return _load(page: _page + 1, query: _query);
  }

  Future<void> _load({required int page, required TQuery query}) async {
    final int request = ++_request;
    final bool isAppending = page > 1;

    _isLoading = true;
    _isAppending = isAppending;
    _failure = null;
    // The query is in force from the moment it is asked for, so a refusal
    // leaves another go retrying the filter the reader chose rather than the
    // one it replaced.
    _query = query;
    publish();

    PagedResult<T>? result;
    ApiException? failure;

    try {
      result = await fetch(page: page, query: query);
    } on ApiException catch (thrown) {
      failure = thrown;
    }

    if (request != _request) {
      return;
    }

    _refusedPage = result == null ? page : null;

    if (result case final PagedResult<T> landed) {
      _page = landed.page;
      _totalCount = landed.totalCount;
      // A page that answers with nothing is the end of the list rather than a
      // reason to drop what has already been read.
      _items = List<T>.unmodifiable(
        isAppending ? <T>[..._items, ...landed.items] : landed.items,
      );
      _hasLanded = true;
    }

    _failure = failure;
    _isLoading = false;
    _isAppending = false;
    publish();
  }
}
