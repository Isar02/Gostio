import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/count_badge.dart';
import 'chat_unread_notifier.dart';

class UnreadMessagesBadge extends StatelessWidget {
  const UnreadMessagesBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final int unread = context.select<ChatUnreadNotifier, int>(
      (ChatUnreadNotifier messages) => messages.unread,
    );

    if (unread == 0) {
      return const SizedBox.shrink();
    }

    return Tooltip(
      message: unread == 1 ? '1 unread message' : '$unread unread messages',
      child: CountBadge(unread),
    );
  }
}
