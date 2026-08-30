import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/paged_result.dart';
import '../../../core/network/api_exception.dart';
import '../data/app_notification.dart';
import '../data/notifications_repository.dart';

class NotificationsNotifier extends ChangeNotifier {
  NotificationsNotifier(this._repository) {
    unawaited(_refreshUnread());
    _poll = Timer.periodic(pollInterval, (Timer _) => _refreshUnread());
  }

  static const Duration pollInterval = Duration(seconds: 30);

  final NotificationsRepository _repository;

  late final Timer _poll;

  int _unread = 0;
  int _page = 1;
  int _totalCount = 0;
  int _countRequest = 0;
  bool _isLoading = false;
  bool _isDisposed = false;
  ApiException? _failure;
  List<AppNotification> _items = const <AppNotification>[];

  int get unread => _unread;

  int get page => _page;

  int get pageSize => PagedResult.defaultPageSize;

  int get totalCount => _totalCount;

  bool get isLoading => _isLoading;

  String? get failureMessage => _failure?.message;

  List<AppNotification> get items => _items;

  Future<void> openPage(int page) {
    _page = page;

    return load();
  }

  Future<void> load() async {
    _isLoading = true;
    _failure = null;
    _publish();

    // The page and the count do not depend on each other.
    final Future<void> counting = _refreshUnread();

    try {
      final PagedResult<AppNotification> page = await _repository.search(
        page: _page,
        pageSize: pageSize,
      );

      _items = page.items;
      _totalCount = page.totalCount;
    } on ApiException catch (failure) {
      _failure = failure;
    }

    await counting;

    _isLoading = false;
    _publish();
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) {
      return;
    }

    _failure = null;

    try {
      final AppNotification read = await _repository.markRead(notification.id);
      _items = <AppNotification>[
        for (final AppNotification item in _items)
          item.id == read.id ? read : item,
      ];

      await _refreshUnread();
    } on ApiException catch (failure) {
      _failure = failure;
    }

    _publish();
  }

  Future<void> markAllRead() async {
    _failure = null;

    try {
      await _repository.markAllRead();
      await load();
    } on ApiException catch (failure) {
      _failure = failure;
      _publish();
    }
  }

  // The one place the count is written, and only the newest read may write it.
  // The poll, a page load and a row marked read all ask for it, so an answer
  // still in flight when a later one is issued is stale by the time it lands.
  // A failed read says nothing: the session already answers a dead token, and
  // anything else is answered by the next tick.
  Future<void> _refreshUnread() async {
    final int request = ++_countRequest;

    try {
      final int unread = await _repository.unreadCount();
      if (request == _countRequest && unread != _unread) {
        _unread = unread;
        _publish();
      }
    } on ApiException {
      return;
    }
  }

  // A call in flight outlives the shell that started it.
  void _publish() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _poll.cancel();

    super.dispose();
  }
}
