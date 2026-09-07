import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/push/push_messaging.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/paged_list.dart';
import '../data/notifications_repository.dart';
import 'notification_card.dart';
import 'notifications_notifier.dart';
import 'unread_notices.dart';

// What the bell opens. It is a screen rather than a panel over one, because a
// panel the width of a phone is a screen with a shadow under it.
//
// A notice names a booking and nothing else, so what a tap opens is handed in
// rather than reached for: the trips this account has made are another
// feature's, and the application is where the two meet.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({this.openBooking, super.key});

  final Future<void> Function(BuildContext context, int reservationId)?
  openBooking;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotificationsNotifier>(
      create: (BuildContext context) => NotificationsNotifier(
        context.read<NotificationsRepository>(),
        context.read<UnreadNotices>(),
        messaging: context.read<PushMessaging>(),
      ),
      child: _Notifications(openBooking: openBooking),
    );
  }
}

class _Notifications extends StatelessWidget {
  const _Notifications({this.openBooking});

  final Future<void> Function(BuildContext context, int reservationId)?
  openBooking;

  @override
  Widget build(BuildContext context) {
    final NotificationsNotifier notices = context
        .watch<NotificationsNotifier>();
    final int unread = context.select<UnreadNotices, int>(
      (UnreadNotices notices) => notices.unread,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          _MarkAll(
            unread: unread,
            isMarking: notices.isMarking,
            onMarkAll: () => _markAll(context, notices),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            // Either write is refused in the same place. One of them is a
            // button in the bar above this and the other is a row below it,
            // and a sentence between the two is beside both of them.
            if (notices.markFailure case final String refusal)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  0,
                ),
                child: AppNotice(refusal),
              ),
            Expanded(
              child: PagedList<AppNotification>(
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
                    NotificationCard(
                      notice,
                      onTap: _tapFor(context, notices, notice),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reading a notice and opening what it is about are one gesture, because
  // opening a notice is reading it. A notice with neither left is not a card
  // the reader can press.
  VoidCallback? _tapFor(
    BuildContext context,
    NotificationsNotifier notices,
    AppNotification notice,
  ) {
    final int? reservationId = notice.reservationId;
    final Future<void> Function(BuildContext, int)? open = openBooking;
    final bool opens = reservationId != null && open != null;

    if (notice.isRead && !opens) {
      return null;
    }

    return () {
      unawaited(notices.markRead(notice));

      if (opens) {
        unawaited(open(context, reservationId));
      }
    };
  }

  Future<void> _markAll(
    BuildContext context,
    NotificationsNotifier notices,
  ) async {
    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Mark everything read?',
      message:
          'Every notice on this account is marked read, including the ones '
          'below what you have loaded. This cannot be undone.',
      confirmLabel: 'Mark all read',
    );

    if (agreed) {
      await notices.markAllRead();
    }
  }
}

// The one bulk write on this screen. It stays where it is with nothing unread
// and says why it is not offered, rather than disappearing and leaving the bar
// a different shape on every visit.
class _MarkAll extends StatelessWidget {
  const _MarkAll({
    required this.unread,
    required this.isMarking,
    required this.onMarkAll,
  });

  final int unread;
  final bool isMarking;
  final VoidCallback onMarkAll;

  @override
  Widget build(BuildContext context) {
    if (isMarking) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Center(
          child: SizedBox(
            width: AppSizes.spinner,
            height: AppSizes.spinner,
            child: CircularProgressIndicator(strokeWidth: AppSizes.stroke),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: unread == 0 ? null : onMarkAll,
      tooltip: unread == 0 ? 'Nothing is unread' : 'Mark all read',
      icon: const Icon(Icons.done_all_rounded),
    );
  }
}
