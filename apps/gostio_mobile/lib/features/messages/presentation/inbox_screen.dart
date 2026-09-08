import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/paged_list.dart';
import '../data/conversations_repository.dart';
import '../data/thread_subject.dart';
import 'chat_nudge.dart';
import 'conversation_card.dart';
import 'inbox_notifier.dart';
import 'open_thread_button.dart';
import 'thread_screen.dart';

// Every thread this account is in, the one that was last spoken in first. A
// row opens the thread it stands for, and what that screen changes comes back
// here as the one row it changed.
//
// This is the tab's body rather than its screen: the bar over it is the
// shell's, because the bell in it belongs to every tab and not to this one.
class InboxScreen extends StatelessWidget {
  const InboxScreen({required this.callerId, super.key});

  final int callerId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InboxNotifier>(
      create: (BuildContext context) => InboxNotifier(
        context.read<ConversationsRepository>(),
        nudge: context.read<ChatNudge?>(),
      ),
      child: _Inbox(callerId: callerId),
    );
  }
}

class _Inbox extends StatelessWidget {
  const _Inbox({required this.callerId});

  final int callerId;

  @override
  Widget build(BuildContext context) {
    final InboxNotifier inbox = context.watch<InboxNotifier>();

    return PagedList<Conversation>(
      items: inbox.threads,
      totalCount: inbox.totalCount,
      noun: 'conversations',
      isLoading: inbox.isLoading,
      isAppending: inbox.isAppending,
      failureMessage: inbox.failureMessage,
      failureTraceId: inbox.failureTraceId,
      onMore: inbox.more,
      onRetry: inbox.retry,
      onRefresh: inbox.reload,
      emptyTitle: 'No messages yet',
      emptyMessage:
          'Write to a host from a listing or a booking and the thread opens '
          'here. Anything else is a question for support.',
      // Support is one entry rather than a thread the reader has to find:
      // above the list where there is one, and inside the empty state where
      // there is not. The list draws whichever of the two it is showing.
      emptyAction: const _AskSupport(),
      header: const _AskSupport(),
      itemBuilder: (BuildContext context, Conversation thread) =>
          ConversationCard(
            thread,
            callerId: callerId,
            onTap: () => unawaited(
              ThreadScreen.open(
                context,
                thread,
                callerId: callerId,
                onThreadChanged: inbox.threadChanged,
              ),
            ),
          ),
    );
  }
}

class _AskSupport extends StatelessWidget {
  const _AskSupport();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: OpenThreadButton(
        subject: WithSupport(),
        label: 'Ask Gostio support',
        icon: Icons.support_agent_rounded,
      ),
    );
  }
}
