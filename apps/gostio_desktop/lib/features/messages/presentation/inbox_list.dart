import 'package:flutter/material.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/count_badge.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/conversation.dart';
import '../data/conversation_participant.dart';
import '../data/message.dart';
import 'conversation_look.dart';
import 'inbox_notifier.dart';

class InboxList extends StatelessWidget {
  const InboxList({
    required this.inbox,
    required this.callerId,
    required this.openId,
    required this.onOpen,
    super.key,
  });

  final InboxNotifier inbox;
  final int callerId;
  final int? openId;
  final ValueChanged<Conversation> onOpen;

  @override
  Widget build(BuildContext context) {
    final String? failure = inbox.failureMessage;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border, width: AppSizes.hairline),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: AppSizes.stroke,
            child: inbox.isLoading ? const LinearProgressIndicator() : null,
          ),
          if (failure != null && inbox.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: AppNotice(failure),
            ),
          Expanded(
            child: inbox.items.isEmpty
                ? _Nothing(inbox: inbox)
                : ListView.builder(
                    itemCount: inbox.items.length,
                    itemExtent: AppSizes.inboxRow,
                    itemBuilder: (BuildContext context, int index) {
                      final Conversation thread = inbox.items[index];

                      return _Row(
                        thread: thread,
                        callerId: callerId,
                        isOpen: thread.id == openId,
                        onOpen: () => onOpen(thread),
                      );
                    },
                  ),
          ),
          PaginationFooter(
            page: inbox.page,
            pageSize: inbox.pageSize,
            totalCount: inbox.totalCount,
            onPageChanged: inbox.openPage,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.thread,
    required this.callerId,
    required this.isOpen,
    required this.onOpen,
  });

  final Conversation thread;
  final int callerId;
  final bool isOpen;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<ConversationParticipant> others = thread.othersThan(callerId);

    return InkWell(
      onTap: onOpen,
      hoverColor: AppColors.hover,
      child: Container(
        decoration: BoxDecoration(
          color: isOpen ? AppColors.selected : null,
          border: const Border(
            bottom: BorderSide(
              color: AppColors.border,
              width: AppSizes.hairline,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            AccountAvatar(
              userId: others.isEmpty ? callerId : others.first.userId,
              name: thread.withWhom(callerId),
              hasImage: others.isNotEmpty && others.first.hasProfileImage,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          thread.withWhom(callerId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: thread.holdsUnread
                              ? text.titleSmall
                              : text.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        AppDates.age(thread.lastActivityAt),
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      StatusChip(thread.type.label, tone: thread.type.tone),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: _Preview(thread: thread)),
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
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.thread});

  final Conversation thread;

  @override
  Widget build(BuildContext context) {
    return Text(
      switch (thread.lastMessage) {
        final Message said => said.body,
        null => 'Nothing has been said in this thread yet.',
      },
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: AppColors.inkMuted),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.inbox});

  final InboxNotifier inbox;

  @override
  Widget build(BuildContext context) {
    if (inbox.isLoading) {
      return const LoadingState();
    }

    if (inbox.failureMessage case final String failure) {
      return ErrorState(
        message: failure,
        onRetry: inbox.reload,
        traceId: inbox.failureTraceId,
      );
    }

    return inbox.query.isEmpty
        ? const EmptyState(
            title: 'No threads',
            message:
                'Guests open these: about a booking, as an enquiry, or to '
                'support. They are answered from this side rather than '
                'started here.',
          )
        : const EmptyState(
            title: 'Nothing matches',
            message: 'No thread is of the kind chosen above.',
          );
  }
}
