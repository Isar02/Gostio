import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/paged_list.dart';
import '../data/conversations_repository.dart';
import 'conversation_card.dart';
import 'inbox_notifier.dart';
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
      create: (BuildContext context) =>
          InboxNotifier(context.read<ConversationsRepository>()),
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
          'Threads with a host about a stay, an experience or a booking are '
          'read here, and so is anything you ask support.',
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
