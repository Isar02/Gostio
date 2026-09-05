import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/paged_list.dart';
import '../data/notifications_repository.dart';
import 'notification_card.dart';
import 'notifications_notifier.dart';

// What the bell opens. It is a screen rather than a panel over one, because a
// panel the width of a phone is a screen with a shadow under it.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotificationsNotifier>(
      create: (BuildContext context) =>
          NotificationsNotifier(context.read<NotificationsRepository>()),
      child: Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: SafeArea(
          child: Consumer<NotificationsNotifier>(
            builder:
                (
                  BuildContext context,
                  NotificationsNotifier notices,
                  Widget? child,
                ) => PagedList<AppNotification>(
                  items: notices.items,
                  totalCount: notices.totalCount,
                  noun: 'notifications',
                  isLoading: notices.isLoading,
                  isAppending: notices.isAppending,
                  failureMessage: notices.failureMessage,
                  failureTraceId: notices.failureTraceId,
                  onMore: notices.more,
                  onRetry: notices.retry,
                  onRefresh: notices.reload,
                  emptyTitle: 'Nothing to report',
                  emptyMessage:
                      'Bookings, payments and refunds are announced here.',
                  itemBuilder: (BuildContext context, AppNotification notice) =>
                      NotificationCard(notice),
                ),
          ),
        ),
      ),
    );
  }
}
