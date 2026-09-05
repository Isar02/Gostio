import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/count_badge.dart';
import 'notifications_screen.dart';
import 'unread_notices.dart';

// The one bell the client has, drawn in whichever tab is being read. The count
// behind it is the shell's, so moving between tabs neither loses it nor asks
// the server for it a second time.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final int unread = context.select<UnreadNotices, int>(
      (UnreadNotices notices) => notices.unread,
    );

    return IconButton(
      // The screen is pushed onto the tab it was opened from, so the bar under
      // it stays and closing it comes back to where the reader was.
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const NotificationsScreen(),
        ),
      ),
      tooltip: unread == 0 ? 'Notifications' : '$unread unread notifications',
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Icon(Icons.notifications_none_rounded),
          if (unread > 0)
            Positioned(
              top: -AppSpacing.sm,
              right: -AppSpacing.sm,
              child: CountBadge(unread),
            ),
        ],
      ),
    );
  }
}
