import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/tone.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/filter_bar.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/app_notification.dart';
import 'notification_filter.dart';
import 'notifications_notifier.dart';

class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final NotificationsNotifier notifications = context
        .watch<NotificationsNotifier>();

    return SizedBox(
      width: AppSizes.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Header(notifications: notifications),
          _Filter(notifications: notifications),
          const Divider(),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: AppSizes.panelHeight),
            child: _Body(notifications: notifications),
          ),
          PaginationFooter(
            page: notifications.page,
            pageSize: notifications.pageSize,
            totalCount: notifications.totalCount,
            onPageChanged: notifications.openPage,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.notifications});

  final NotificationsNotifier notifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Text('Notifications', style: Theme.of(context).textTheme.titleSmall),
          const Spacer(),
          Tooltip(
            message: notifications.unread == 0
                ? 'Everything here has already been read'
                : 'Mark all ${notifications.unread} unread as read',
            child: TextButton(
              onPressed: notifications.unread == 0
                  ? null
                  : notifications.markAllRead,
              child: const Text('Mark all read'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.notifications});

  final NotificationsNotifier notifications;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilterField(
          label: 'Show',
          child: AppDropdown<NotificationFilter>(
            value: notifications.query,
            values: NotificationFilter.values,
            labels: (NotificationFilter filter) => filter.label,
            onChanged: notifications.apply,
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.notifications});

  final NotificationsNotifier notifications;

  @override
  Widget build(BuildContext context) {
    if (notifications.isLoading && notifications.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xxl),
        child: LoadingState(),
      );
    }

    final String? failure = notifications.failureMessage;

    if (notifications.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: failure == null
            ? _emptyState(notifications.query)
            : ErrorState(message: failure, onRetry: notifications.reload),
      );
    }

    // A page of rows, not a lazy list: the panel is measured for its
    // intrinsic width, which a shrink-wrapped viewport cannot answer.
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (failure case final String message)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                0,
              ),
              child: AppNotice(message),
            ),
          for (final AppNotification item in notifications.items)
            _Row(
              notification: item,
              onRead: () => notifications.markRead(item),
            ),
        ],
      ),
    );
  }
}

EmptyState _emptyState(NotificationFilter filter) => switch (filter) {
  NotificationFilter.all => const EmptyState(
    title: 'Nothing yet',
    message: 'Bookings, payments and refunds are announced here.',
  ),
  _ => EmptyState(
    title: 'Nothing here',
    message: 'No notification is ${filter.label.toLowerCase()}.',
  ),
};

class _Row extends StatelessWidget {
  const _Row({required this.notification, required this.onRead});

  final AppNotification notification;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Tone tone = notification.kind.tone;

    return InkWell(
      onTap: notification.isRead ? null : onRead,
      hoverColor: AppColors.hover,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: tone.ground,
                borderRadius: AppRadii.medium,
              ),
              child: Icon(
                notification.kind.icon,
                size: AppSizes.iconSmall,
                color: tone.foreground,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    notification.title,
                    style: notification.isRead
                        ? text.bodyMedium
                        : text.titleSmall,
                  ),
                  Text(
                    notification.body,
                    style: text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Tooltip(
                    message: AppDates.dateTime(notification.createdAt),
                    child: Text(
                      AppDates.age(notification.createdAt),
                      style: text.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: AppSizes.dot,
                height: AppSizes.dot,
                margin: const EdgeInsets.only(top: AppSpacing.xs),
                decoration: const BoxDecoration(
                  color: AppColors.indigo,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension on NotificationKind {
  IconData get icon => switch (this) {
    NotificationKind.reservationCreated => Icons.event_available_outlined,
    NotificationKind.reservationStatusChanged => Icons.swap_horiz,
    NotificationKind.paymentSucceeded => Icons.payments_outlined,
    NotificationKind.refundProcessed => Icons.undo,
    NotificationKind.hostVerificationDecided => Icons.verified_user_outlined,
    NotificationKind.unknown => Icons.notifications_none,
  };

  Tone get tone => switch (this) {
    NotificationKind.reservationCreated => Tone.informative,
    NotificationKind.reservationStatusChanged => Tone.neutral,
    NotificationKind.paymentSucceeded => Tone.positive,
    NotificationKind.refundProcessed => Tone.attention,
    NotificationKind.hostVerificationDecided => Tone.informative,
    NotificationKind.unknown => Tone.neutral,
  };
}
