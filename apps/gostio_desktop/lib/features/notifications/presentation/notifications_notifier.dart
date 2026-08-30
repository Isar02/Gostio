import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/paged_result.dart';
import '../../../core/network/api_exception.dart';
import '../data/app_notification.dart';
import '../data/notifications_repository.dart';

class NotificationsNotifier extends ChangeNotifier {
  NotificationsNotifier(this._repository) {
    unawaited(_countUnread());
    _poll = Timer.periodic(pollInterval, (Timer _) => _countUnread());
  }

  static const Duration pollInterval = Duration(seconds: 30);

  final NotificationsRepository _repository;

  late final Timer _poll;

  int _unread = 0;
  bool _isCounting = false;
  bool _isLoading = false;
  bool _isDisposed = false;
  ApiException? _failure;
  List<AppNotification> _items = const <AppNotification>[];

  int get unread => _unread;

  bool get isLoading => _isLoading;

  String? get failureMessage => _failure?.message;

  List<AppNotification> get items => _items;

  Future<void> load() async {
    _isLoading = true;
    _failure = null;
    _publish();

    try {
      final (PagedResult<AppNotification> page, int unread) = await (
        _repository.recent(),
        _repository.unreadCount(),
      ).wait;

      _items = page.items;
      _unread = unread;
    } on ApiException catch (failure) {
      _failure = failure;
    }

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
      _unread = _unread > 0 ? _unread - 1 : 0;
    } on ApiException catch (failure) {
      _failure = failure;
    }

    _publish();
  }

  Future<void> markAllRead() async {
    _failure = null;
    try {
      _unread = await _repository.markAllRead();
      await load();
    } on ApiException catch (failure) {
      _failure = failure;
      _publish();
    }
  }

  // The count is polled, so its failures are silent: the session already
  // answers a dead token, and anything else is answered by the next tick.
  Future<void> _countUnread() async {
    if (_isCounting) {
      return;
    }

    _isCounting = true;
    try {
      final int unread = await _repository.unreadCount();
      if (unread != _unread) {
        _unread = unread;
        _publish();
      }
    } on ApiException {
      // Nothing to say.
    } finally {
      _isCounting = false;
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
