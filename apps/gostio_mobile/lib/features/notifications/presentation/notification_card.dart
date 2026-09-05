import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';

// One notice as a row. What raised it is said in an icon, when it arrived is
// read against now rather than printed as a date to subtract, and one that has
// not been read yet says so in a word as well as in a colour.
class NotificationCard extends StatelessWidget {
  const NotificationCard(this.notice, {super.key});

  final AppNotification notice;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String age = AppDates.age(notice.createdAt);

    return AppCard(
      semanticLabel: <String>[
        if (!notice.isRead) 'Unread',
        notice.title,
        notice.body,
        age,
      ].join('. '),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Mark(notice.kind, isRead: notice.isRead),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(notice.title, style: text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  notice.body,
                  style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Text(age, style: text.labelSmall),
                    if (!notice.isRead) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      const StatusChip('Unread', tone: Tone.informative),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// The icon a notice is recognised by before its words are read. A kind this
// build has not caught up with is still a notice and is drawn as the plain
// bell rather than dropped.
class _Mark extends StatelessWidget {
  const _Mark(this.kind, {required this.isRead});

  final NotificationKind kind;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final Tone tone = isRead ? Tone.neutral : Tone.informative;

    return Container(
      width: AppSizes.iconTile,
      height: AppSizes.iconTile,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.ground,
        borderRadius: AppRadii.medium,
      ),
      child: Icon(_icon, size: AppSizes.icon, color: tone.foreground),
    );
  }

  IconData get _icon => switch (kind) {
    NotificationKind.reservationCreated => Icons.event_available_rounded,
    NotificationKind.reservationStatusChanged => Icons.event_repeat_rounded,
    NotificationKind.paymentSucceeded => Icons.payments_outlined,
    NotificationKind.refundProcessed => Icons.undo_rounded,
    NotificationKind.hostVerificationDecided => Icons.verified_user_outlined,
    NotificationKind.unknown => Icons.notifications_none_rounded,
  };
}
