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
  bool _itemsBelongToQuery = false;
  int? _refusedPage;
  bool _refusedSharesItems = false;
  bool _refusedAppending = false;
  bool _activeLoadSharesItems = false;
  TQuery _query;
  ApiException? _failure;
  List<T> _items = List<T>.empty();
  final List<_PendingEdit<T>> _pendingEdits = <_PendingEdit<T>>[];
  bool Function(T held, T arrived)? _sameItem;

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

  // Whether the rows being held were read for the query now in force. A new
  // query deliberately keeps the previous rows so filter screens can leave
  // them visible behind a refusal, but a caller that cannot mix two queries
  // can use this to withhold them until the replacement lands.
  bool get itemsBelongToQuery => _itemsBelongToQuery;

  bool get hasMore => _items.length < _totalCount;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  @protected
  Future<PagedResult<T>> fetch({required int page, required TQuery query});

  Future<void> apply(TQuery query) =>
      _load(page: 1, query: query, sharesItems: false);

  Future<void> reload() => _load(page: 1, query: _query, sharesItems: true);

  // Another go at the read that was refused, which is not the same as asking
  // for more. A filter that failed left the list showing the results of the
  // filter before it, and fetching page two of the new query onto those would
  // hand the reader one list built out of two.
  Future<void> retry() {
    final int? refused = _refusedPage;

    return refused == null
        ? Future<void>.value()
        : _load(
            page: refused,
            query: _query,
            sharesItems: _refusedSharesItems,
            appending: _refusedAppending,
          );
  }

  // An offset is counted in rows, not pages: taking one down slides everything
  // after it forward. So the page asked for is the one the first uncovered row
  // falls in, and the part of it already held is dropped on arrival.
  Future<void> more() {
    if (_isLoading || !_hasLanded || !hasMore) {
      return Future<void>.value();
    }

    return _load(
      page: _covered ~/ pageSize + 1,
      query: _query,
      sharesItems: true,
      appending: true,
    );
  }

  // The rows held are always a prefix of the server's list, so how far this
  // window reaches is how many of them there are.
  int get _covered => _items.length;

  // One row the reader changed on a screen this list opened. What has already
  // been read stays where it is: reading the list again would take one several
  // pages deep back to its first page to show a single changed row.
  @protected
  void replaceWhere(bool Function(T item) matches, T item) {
    final int at = _items.indexWhere(matches);
    if (at < 0) {
      return;
    }

    _remember(matches, item: item);
    _items = List<T>.unmodifiable(<T>[..._items]..[at] = item);
    publish();
  }

  // One row the reader took down on a screen this list opened. The whole is
  // one shorter as well, so the footer says how much of it is being held
  // rather than counting a row nobody can reach any more.
  @protected
  void removeWhere(bool Function(T item) matches) {
    final int at = _items.indexWhere(matches);
    if (at < 0) {
      return;
    }

    _remember(matches);
    _items = List<T>.unmodifiable(<T>[..._items]..removeAt(at));
    _shrink();
    publish();
  }

  // The newest page read again while the reader is looking at the list, merged
  // into what they are already holding rather than replacing it. A list the
  // server orders newest first grows at the front, so a row the answer carries
  // that this list does not hold is a new one and keeps the place the server
  // gave it; a row it does hold is replaced, which is how a change made
  // somewhere else catches up. Pages below the first are left exactly as they
  // are, and so is the scroll.
  //
  // This is not `reload`. A reader several pages deep who is sent back to the
  // first one every interval is worse off than one who is never told anything.
  @protected
  void mergeNewest(
    PagedResult<T> newest, {
    required bool Function(T held, T arrived) isSame,
  }) {
    if (isDisposed || !_hasLanded) {
      return;
    }

    _sameItem = isSame;
    final List<T> merged = <T>[];

    for (final T arrived in newest.items) {
      final int at = _items.indexWhere((T held) => isSame(held, arrived));
      if (at < 0) {
        merged.add(arrived);
      }
    }

    _items = List<T>.unmodifiable(<T>[
      ...merged,
      for (final T held in _items)
        newest.items.firstWhere(
          (T arrived) => isSame(held, arrived),
          orElse: () => held,
        ),
    ]);
    _totalCount = newest.totalCount;
    publish();
  }

  // A page already on its way was read before this row changed. Remember what
  // happened to it for that request, so its older answer cannot put the row
  // back the way it was after the write has landed.
  void _remember(bool Function(T item) matches, {T? item}) {
    if (_isLoading) {
      _pendingEdits.add(
        _PendingEdit<T>(
          _request,
          matches: matches,
          item: item,
          decrementsLandedTotal: item == null && _activeLoadSharesItems,
        ),
      );
    }
  }

  Future<void> _load({
    required int page,
    required TQuery query,
    required bool sharesItems,
    bool appending = false,
  }) async {
    final int request = ++_request;
    final bool isAppending = appending;

    // Read now, not when the answer lands: a merge arriving in the meantime
    // moves every offset, and the page in flight was asked for under these.
    final int covered = _covered;

    _isLoading = true;
    _isAppending = isAppending;
    _activeLoadSharesItems = sharesItems;
    if (!sharesItems) {
      _itemsBelongToQuery = false;
    }
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
      _forget(request);

      return;
    }

    _refusedPage = result == null ? page : null;
    _refusedSharesItems = result == null ? sharesItems : false;
    _refusedAppending = result == null ? isAppending : false;

    if (result case final PagedResult<T> landed) {
      final List<T> arrived = isAppending
          ? _notYetHeld(landed, covered)
          : landed.items;

      _page = landed.page;
      _totalCount = landed.totalCount;
      // A page that answers with nothing is the end of the list rather than a
      // reason to drop what has already been read.
      _items = _reconcile(
        isAppending ? _appendWithoutDuplicates(arrived) : arrived,
        request,
      );
      _hasLanded = true;
      _itemsBelongToQuery = true;
    }

    _forget(request);

    _failure = failure;
    _isLoading = false;
    _isAppending = false;
    publish();
  }

  List<T> _reconcile(List<T> landed, int request) {
    final List<T> reconciled = List<T>.of(landed);

    for (final _PendingEdit<T> edit in _pendingEdits.where(
      (_PendingEdit<T> held) => held.request == request,
    )) {
      final int at = reconciled.indexWhere(edit.matches);
      final T? item = edit.item;
      if (item == null) {
        if (at >= 0) {
          reconciled.removeAt(at);
        }

        // A refresh or append reports the count from before the deletion even
        // when the deleted row is not part of the page that arrived.
        if (edit.decrementsLandedTotal || at >= 0) {
          _shrink();
        }
      } else {
        if (at >= 0) {
          reconciled[at] = item;
        }
      }
    }

    return List<T>.unmodifiable(reconciled);
  }

  // What a page carries past the end of the window as it was when the page was
  // asked for. Anything that moved since shifts the page and the window
  // together, so it cancels out.
  List<T> _notYetHeld(PagedResult<T> landed, int covered) {
    final int shared = covered - ((landed.page - 1) * pageSize);

    return shared <= 0
        ? landed.items
        : landed.items.skip(shared).toList(growable: false);
  }

  // A newest-page merge shifts every later offset page. The first row of the
  // next page can therefore already be held; append only the rows that are not.
  List<T> _appendWithoutDuplicates(List<T> arrived) {
    final bool Function(T held, T arrived)? isSame = _sameItem;
    if (isSame == null) {
      return <T>[..._items, ...arrived];
    }

    return <T>[
      ..._items,
      for (final T item in arrived)
        if (!_items.any((T held) => isSame(held, item))) item,
    ];
  }

  void _forget(int request) => _pendingEdits.removeWhere(
    (_PendingEdit<T> edit) => edit.request == request,
  );

  void _shrink() {
    if (_totalCount > 0) {
      _totalCount--;
    }
  }
}

// What a screen this list opened did to one of its rows: handed back a newer
// row, or took the row away. A pending edit carries the request that was in
// flight when it happened, so an older answer can be reconciled with it rather
// than replacing it.
class _PendingEdit<T> {
  const _PendingEdit(
    this.request, {
    required this.matches,
    required this.decrementsLandedTotal,
    this.item,
  });

  final int request;
  final bool Function(T item) matches;
  final bool decrementsLandedTotal;
  final T? item;
}
