import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/chat_hub.dart';
import '../data/conversation_query.dart';
import '../data/conversations_repository.dart';
import '../data/messages_repository.dart';
import 'chat_unread_notifier.dart';
import 'conversation_filters.dart';
import 'inbox_list.dart';
import 'inbox_notifier.dart';
import 'thread_notifier.dart';
import 'thread_view.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    required this.signedInUserId,
    required this.onlyThreadsJoined,
    super.key,
  });

  final int signedInUserId;

  // An administrator reaches every support thread; a host only the ones they
  // are in. Asking for their own is what narrows the wider view.
  final bool onlyThreadsJoined;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  Conversation? _open;

  void _openThread(Conversation thread) => setState(() => _open = thread);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InboxNotifier>(
      create: (BuildContext context) {
        final InboxNotifier inbox = InboxNotifier(
          context.read<ConversationsRepository>(),
          query: ConversationQuery(
            joinedBy: widget.onlyThreadsJoined ? widget.signedInUserId : null,
          ),
        );
        unawaited(inbox.reload());

        return inbox;
      },
      child: _Body(
        callerId: widget.signedInUserId,
        chosen: _open,
        onOpen: _openThread,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.callerId,
    required this.chosen,
    required this.onOpen,
  });

  final int callerId;
  final Conversation? chosen;
  final ValueChanged<Conversation> onOpen;

  @override
  Widget build(BuildContext context) {
    final InboxNotifier inbox = context.watch<InboxNotifier>();

    final Conversation? open = switch (chosen) {
      final Conversation thread => inbox.holding(thread.id) ?? thread,
      null => null,
    };

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ConversationFilters(
            applied: inbox.query,
            isLoading: inbox.isLoading,
            onChanged: inbox.apply,
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: AppSizes.inbox,
                  child: InboxList(
                    inbox: inbox,
                    callerId: callerId,
                    openId: open?.id,
                    onOpen: onOpen,
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: switch (open) {
                    final Conversation thread => _Thread(
                      thread: thread,
                      callerId: callerId,
                      inbox: inbox,
                    ),
                    null => const _NoThread(),
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread({
    required this.thread,
    required this.callerId,
    required this.inbox,
  });

  final Conversation thread;
  final int callerId;
  final InboxNotifier inbox;

  @override
  Widget build(BuildContext context) {
    final ChatUnreadNotifier waiting = context.read<ChatUnreadNotifier>();

    return ChangeNotifierProvider<ThreadNotifier>(
      key: ValueKey<int>(thread.id),
      create: (BuildContext context) {
        final ThreadNotifier lines = ThreadNotifier(
          context.read<MessagesRepository>(),
          context.read<ChatHub>(),
          conversationId: thread.id,
          callerId: callerId,
          onRead: (int unread) {
            waiting.report(unread);
            unawaited(inbox.refreshQuietly());
          },
        );
        unawaited(lines.open());

        return lines;
      },
      child: ThreadView(thread: thread, callerId: callerId),
    );
  }
}

class _NoThread extends StatelessWidget {
  const _NoThread();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border, width: AppSizes.hairline),
      ),
      child: const EmptyState(
        title: 'No thread open',
        message: 'Choose one on the left to read it and answer it.',
      ),
    );
  }
}
