import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../../../core/push/push_messaging.dart';
import '../../../core/push/push_notice.dart';
import '../../../core/state/foreground_poll.dart';
import '../data/notifications_repository.dart';
import 'unread_notices.dart';

// The bell's list, newest first, as the server orders it. It has no filter of
// its own, so the query it pages under carries nothing.
//
// **It keeps itself current while it is open.** The count over the bell is
// polled for the whole client, and a list that only changed when the reader
// pulled on it would be the one screen in this client where something can
// arrive and not be shown. The same rule the count is polled under applies
// here — read while the application is in front of the reader, stopped behind
// it — and a delivery that arrives in the meantime brings the read forward.
//
// Both writes on this screen change what the bell is counting, so the count is
// held here rather than read a second time by whoever drew the figure.
class NotificationsNotifier extends PagedNotifier<AppNotification, void> {
  NotificationsNotifier(
    this._repository,
    this._unread, {
    PushMessaging? messaging,
  }) : super(null) {
    // A delivery that arrives while this screen is in front of the reader is
    // the one row it does not have. Nothing is drawn over the screen for it;
    // what it is worth is the list being current without waiting out the poll.
    _arrivals = messaging?.arrivals.listen(
      (PushNotice _) => unawaited(catchUp()),
    );
    _poll = ForegroundPoll(catchUp);
    unawaited(reload());
  }

  final NotificationsRepository _repository;
  final UnreadNotices _unread;

  late final ForegroundPoll _poll;
  StreamSubscription<PushNotice>? _arrivals;
  bool _isMarking = false;
  bool _isCatchingUp = false;
  int _listRevision = 0;
  ApiException? _markFailure;

  // One write at a time over the whole screen. Marking every notice read while
  // one of them is being marked would leave two answers competing to say what
  // the list holds.
  bool get isMarking => _isMarking;

  String? get markFailure => _markFailure?.message;

  @override
  @protected
  Future<PagedResult<AppNotification>> fetch({
    required int page,
    required void query,
  }) => _repository.search(page: page, pageSize: pageSize);

  // The newest page read again and merged into what the reader is holding, so
  // a notice that arrived shows up where the server put it and one read
  // elsewhere catches up — without the list going back to its first page under
  // a reader who has asked for more of it.
  //
  // A tick that lands while the reader is loading, marking or already catching
  // up is dropped rather than queued: nothing was promised, and the next one is
  // thirty seconds away.
  Future<void> catchUp() async {
    if (_isCatchingUp || _isMarking || isLoading || !hasLanded) {
      return;
    }

    _isCatchingUp = true;
    final int revision = _listRevision;

    try {
      final PagedResult<AppNotification> newest = await _repository.search(
        page: 1,
        pageSize: pageSize,
      );

      if (revision == _listRevision) {
        mergeNewest(
          newest,
          isSame: (AppNotification held, AppNotification arrived) =>
              held.id == arrived.id,
        );
      }
    } on ApiException {
      // A refused quiet read is not a refusal the reader asked for. What is on
      // the screen stays, and the next tick says so anyway.
      return;
    } finally {
      _isCatchingUp = false;
    }
  }

  // The row the server answers is what the list draws from then on. What is
  // left unread is asked for rather than subtracted: the count is the
  // server's figure and one notice read here is not the only way it moves.
  Future<void> markRead(AppNotification notice) async {
    if (_isMarking || notice.isRead) {
      return;
    }

    _begin();

    try {
      final AppNotification read = await _repository.markRead(notice.id);
      if (isDisposed) {
        return;
      }

      replaceWhere((AppNotification held) => held.id == read.id, read);
      unawaited(_unread.refresh());
    } on ApiException catch (refused) {
      _markFailure = refused;
    } finally {
      _end();
    }
  }

  // Every notice this account holds, not only the ones read into the list, so
  // the list is read again rather than rewritten here. That is the honest
  // answer: the pages this client has are a part of what just changed, and a
  // row it marked itself would be a mark it invented.
  Future<void> markAllRead() async {
    if (_isMarking) {
      return;
    }

    _begin();

    try {
      // The count registers the write when it begins, so a poll that started
      // later cannot be undone by this answer arriving after it. It is the one
      // wait here, because it is the write's own answer read through the count.
      await _unread.report(_repository.markAllRead());
    } on ApiException catch (refused) {
      _markFailure = refused;
      _end();

      return;
    }

    if (isDisposed) {
      return;
    }

    _end();
    await reload();
  }

  @override
  void dispose() {
    _poll.dispose();
    unawaited(_arrivals?.cancel());

    super.dispose();
  }

  void _begin() {
    // A quiet read already in flight saw the list before this write. Its answer
    // may update nothing after the write begins, or it could restore stale rows.
    _listRevision++;
    _isMarking = true;
    _markFailure = null;
    publish();
  }

  void _end() {
    if (!isDisposed) {
      _isMarking = false;
      publish();
    }
  }
}
