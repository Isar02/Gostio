import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/paged_result.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/paging/paged_notifier.dart';
import '../data/app_notification.dart';
import '../data/notifications_repository.dart';
import 'notification_filter.dart';

class NotificationsNotifier
    extends PagedNotifier<AppNotification, NotificationFilter> {
  NotificationsNotifier(this._repository) : super(NotificationFilter.all) {
    unawaited(_refreshUnread());
    _poll = Timer.periodic(pollInterval, (Timer _) => _refreshUnread());
  }

  static const Duration pollInterval = Duration(seconds: 30);

  final NotificationsRepository _repository;

  late final Timer _poll;

  int _unread = 0;
  int _countRequest = 0;

  int get unread => _unread;

  @override
  @protected
  Future<PagedResult<AppNotification>> fetch({
    required int page,
    required NotificationFilter query,
  }) =>
      _repository.search(page: page, pageSize: pageSize, isRead: query.isRead);

  // The count does not depend on the page, so it is issued beside it.
  @override
  @protected
  Future<void> load({
    required int page,
    required NotificationFilter query,
    bool quietly = false,
  }) async {
    final Future<void> counting = _refreshUnread();

    await super.load(page: page, query: query, quietly: quietly);
    await counting;
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) {
      return;
    }

    await performAndReload(() => _repository.markRead(notification.id));
  }

  Future<void> markAllRead() => performAndReload(_repository.markAllRead);

  // Several callers ask for the count, so only the newest read may write it:
  // an answer still in flight when a later one is issued is stale when it lands.
  Future<void> _refreshUnread() async {
    final int request = ++_countRequest;

    try {
      final int unread = await _repository.unreadCount();
      if (request == _countRequest && unread != _unread) {
        _unread = unread;
        publish();
      }
    } on ApiException {
      return;
    }
  }

  @override
  void dispose() {
    _poll.cancel();

    super.dispose();
  }
}
