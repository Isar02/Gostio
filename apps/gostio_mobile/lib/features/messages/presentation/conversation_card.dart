import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/count_badge.dart';
import 'conversation_look.dart';

// One thread as a row: who it is with, what it is about, the last thing said
// in it, when that was, and how much of it the reader has not seen.
class ConversationCard extends StatelessWidget {
  const ConversationCard(
    this.thread, {
    required this.callerId,
    this.onTap,
    super.key,
  });

  final Conversation thread;
  final int callerId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final String age = AppDates.age(thread.lastActivityAt);

    return AppCard(
      onTap: onTap,
      semanticLabel: _spoken(age),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _Mark(thread),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        thread.titleFor(callerId),
                        style: text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      age,
                      style: text.labelSmall?.copyWith(
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ],
                ),
                if (thread.about case final String about) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    about,
                    style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _preview,
                        style: text.bodyMedium?.copyWith(
                          color: thread.holdsUnread
                              ? AppColors.ink
                              : AppColors.inkMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (thread.holdsUnread) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      CountBadge(thread.unreadCount),
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

  // The last line, said by whoever said it. A thread with nothing in it is one
  // that was just opened, and it says that rather than drawing an empty line.
  String get _preview => switch (thread.lastMessage) {
    final Message said when said.senderUserId == callerId =>
      'You: ${said.body}',
    final Message said => said.body,
    null => 'No messages yet',
  };

  String _spoken(String age) => <String>[
    if (thread.holdsUnread)
      AppNumbers.counted(thread.unreadCount, 'unread message'),
    thread.titleFor(callerId),
    ?thread.about,
    _preview,
    age,
  ].join('. ');
}

// What a thread is recognised by before its words are read.
class _Mark extends StatelessWidget {
  const _Mark(this.thread);

  final Conversation thread;

  @override
  Widget build(BuildContext context) {
    final Tone tone = thread.holdsUnread ? Tone.informative : thread.tone;

    return Container(
      width: AppSizes.iconTile,
      height: AppSizes.iconTile,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.ground,
        borderRadius: AppRadii.medium,
      ),
      child: Icon(thread.mark, size: AppSizes.icon, color: tone.foreground),
    );
  }
}
