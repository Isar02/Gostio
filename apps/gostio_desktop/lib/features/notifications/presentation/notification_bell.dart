import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/count_badge.dart';
import 'notifications_notifier.dart';
import 'notifications_panel.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final int unread = context.select<NotificationsNotifier, int>(
      (NotificationsNotifier notifications) => notifications.unread,
    );

    return MenuAnchor(
      alignmentOffset: const Offset(-(AppSizes.panel - AppSizes.control), 0),
      menuChildren: const <Widget>[NotificationsPanel()],
      builder: (BuildContext context, MenuController menu, Widget? child) =>
          IconButton(
            tooltip: unread == 0
                ? 'Notifications'
                : '$unread unread notifications',
            onPressed: () {
              if (menu.isOpen) {
                menu.close();
              } else {
                menu.open();
                unawaited(context.read<NotificationsNotifier>().openPage(1));
              }
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                const Icon(Icons.notifications_none),
                if (unread > 0)
                  Positioned(
                    top: -AppSpacing.xs,
                    right: -AppSpacing.sm,
                    child: CountBadge(unread),
                  ),
              ],
            ),
          ),
    );
  }
}
