import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/notifications_repository.dart';

// The bell's list, newest first, as the server orders it. It has no filter of
// its own, so the query it pages under carries nothing.
class NotificationsNotifier extends PagedNotifier<AppNotification, void> {
  NotificationsNotifier(this._repository) : super(null) {
    unawaited(reload());
  }

  final NotificationsRepository _repository;

  @override
  @protected
  Future<PagedResult<AppNotification>> fetch({
    required int page,
    required void query,
  }) => _repository.search(page: page, pageSize: pageSize);
}
