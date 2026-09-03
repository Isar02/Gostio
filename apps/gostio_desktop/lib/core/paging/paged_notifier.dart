import 'package:flutter/foundation.dart';

import '../models/paged_result.dart';
import '../network/api_exception.dart';
import '../state/screen_notifier.dart';

// The state behind a list: one page of rows, the query they were fetched
// under, and the failure of the last attempt. Only the newest load may write,
// and it writes the page, the query and the rows together, so a request that
// is overtaken or refused leaves the previous view whole.
abstract class PagedNotifier<T, TQuery> extends ScreenNotifier {
  PagedNotifier(this._query);

  int _page = 1;
  int _totalCount = 0;
  int _request = 0;
  bool _isLoading = false;
  TQuery _query;
  ApiException? _failure;
  List<T> _items = List<T>.empty();

  int get page => _page;

  int get pageSize => PagedResult.defaultPageSize;

  int get totalCount => _totalCount;

  bool get isLoading => _isLoading;

  TQuery get query => _query;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  List<T> get items => _items;

  @protected
  Future<PagedResult<T>> fetch({required int page, required TQuery query});

  Future<void> openPage(int page) => load(page: page, query: _query);

  Future<void> apply(TQuery query) => load(page: 1, query: query);

  Future<void> reload() => load(page: _page, query: _query);

  // Announces nothing until it lands, drops a failure nobody asked for, and
  // stands aside for a load already in flight.
  Future<void> refreshQuietly() => _isLoading
      ? Future<void>.value()
      : load(page: _page, query: _query, quietly: true);

  @protected
  Future<void> load({
    required int page,
    required TQuery query,
    bool quietly = false,
  }) async {
    final int request = ++_request;

    if (!quietly) {
      _isLoading = true;
      _failure = null;
      publish();
    }

    PagedResult<T>? result;
    ApiException? failure;

    try {
      PagedResult<T> fetched = await fetch(page: page, query: query);

      // A write can empty the page that asked for it, so the count the server
      // answered leads back to the last page that still exists.
      final int lastPage = PagedResult.pagesFor(
        totalCount: fetched.totalCount,
        pageSize: pageSize,
      );
      if (page > lastPage) {
        page = lastPage;
        fetched = await fetch(page: page, query: query);
      }

      result = fetched;
    } on ApiException catch (thrown) {
      failure = thrown;
    }

    if (request != _request) {
      return;
    }

    if (quietly && result == null) {
      return;
    }

    if (result != null) {
      _page = page;
      _query = query;
      _items = result.items;
      _totalCount = result.totalCount;
    }

    _failure = failure;
    _isLoading = false;
    onLoaded(landed: result != null);
    publish();
  }

  // Called once this request's answer has been written, and never for one that
  // was overtaken, so a subclass holding state of its own writes it under the
  // same publish rather than a rebuild later.
  @protected
  void onLoaded({required bool landed}) {}

  @protected
  Future<void> performAndReload(Future<void> Function() action) async {
    _failure = null;

    try {
      await action();
    } on ApiException catch (failure) {
      _failure = failure;
      publish();

      return;
    }

    await reload();
  }
}
