import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/chat_hub.dart';
import '../data/conversations_repository.dart';
import '../data/messages_repository.dart';
import 'conversation_look.dart';
import 'message_bubble.dart';
import 'message_composer.dart';
import 'thread_notifier.dart';
import 'unread_messages.dart';

// One thread, read from the bottom. This is the one list on the client that is
// not the shared paged list: a conversation is read newest last, so a page
// that arrives is added above what is on the screen rather than below it, and
// the control that asks for it sits at the top where the older lines are.
class ThreadScreen extends StatelessWidget {
  const ThreadScreen(
    this.thread, {
    required this.callerId,
    this.onThreadChanged,
    super.key,
  });

  static Future<void> open(
    BuildContext context,
    Conversation thread, {
    required int callerId,
    ValueChanged<Conversation>? onThreadChanged,
  }) => Navigator.of(
    context,
  ).push(route(thread, callerId: callerId, onThreadChanged: onThreadChanged));

  // The route apart from the push, for a caller holding a navigator rather
  // than a context it may still use.
  static Route<void> route(
    Conversation thread, {
    required int callerId,
    ValueChanged<Conversation>? onThreadChanged,
  }) => MaterialPageRoute<void>(
    builder: (BuildContext context) => ThreadScreen(
      thread,
      callerId: callerId,
      onThreadChanged: onThreadChanged,
    ),
  );

  final Conversation thread;
  final int callerId;

  // The row the list this was opened from is showing. That list read the row
  // before the reader was in the thread, so what happens here goes back to it.
  final ValueChanged<Conversation>? onThreadChanged;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ThreadNotifier>(
      create: (BuildContext context) => ThreadNotifier(
        context.read<MessagesRepository>(),
        context.read<ConversationsRepository>(),
        context.read<ChatHub>(),
        thread,
        callerId: callerId,
        onThreadChanged: onThreadChanged,
        onUnread: context.read<UnreadMessages>().report,
      ),
      child: const _Thread(),
    );
  }
}

class _Thread extends StatefulWidget {
  const _Thread();

  @override
  State<_Thread> createState() => _ThreadState();
}

class _ThreadState extends State<_Thread> {
  final TextEditingController _body = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Asked after the frame that mounts this rather than during it: a notifier
    // that published from inside initState would be dirtying the tree it is
    // being built into.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        unawaited(context.read<ThreadNotifier>().open());
      }
    });
  }

  @override
  void dispose() {
    _body.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThreadNotifier thread = context.watch<ThreadNotifier>();

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _body,
      builder: (BuildContext context, TextEditingValue written, Widget? _) =>
          DiscardGuard(
            hasInput: written.text.trim().isNotEmpty,
            title: 'Leave this message?',
            message:
                'What you have written has not been sent and will not be kept.',
            child: Scaffold(
              appBar: _ThreadBar(thread),
              body: SafeArea(
                child: Column(
                  children: <Widget>[
                    Expanded(child: _Lines(thread)),
                    // The refusal is held beside the button that earned it
                    // rather than at the end of the lines, where a reader who
                    // had just pressed send would have to go looking for it.
                    if (thread.sendFailureMessage case final String refused)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: AppNotice(refused),
                      ),
                    MessageComposer(
                      body: _body,
                      isSending: thread.isSending,
                      refusal: thread.bodyRefusal,
                      onSend: thread.send,
                      onChanged: thread.bodyChanged,
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

class _ThreadBar extends StatelessWidget implements PreferredSizeWidget {
  const _ThreadBar(this.thread);

  final ThreadNotifier thread;

  @override
  Size get preferredSize => const Size.fromHeight(AppSizes.appBar);

  @override
  Widget build(BuildContext context) {
    final Conversation held = thread.thread;

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            held.titleFor(thread.callerId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (held.about case final String about)
            Text(
              about,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.inkMuted),
            ),
        ],
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines(this.thread);

  final ThreadNotifier thread;

  @override
  Widget build(BuildContext context) {
    final List<Message> lines = thread.lines;

    if (lines.isEmpty) {
      if (thread.isLoading) {
        return const LoadingState();
      }

      if (thread.failureMessage case final String message) {
        return ErrorState(
          message: message,
          traceId: thread.failureTraceId,
          onRetry: thread.open,
        );
      }

      return const EmptyState(
        title: 'Nothing said yet',
        message: 'Whatever you write here reaches them as soon as you send it.',
        icon: Icons.chat_bubble_outline_rounded,
      );
    }

    final bool hasTop =
        thread.hasEarlier ||
        thread.isReadingEarlier ||
        thread.failureMessage != null;

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      itemCount: lines.length + (hasTop ? 1 : 0),
      itemBuilder: (BuildContext context, int index) {
        if (index == lines.length) {
          return _Earlier(thread);
        }

        final Message line = lines[index];
        final Message? older = index + 1 < lines.length
            ? lines[index + 1]
            : null;

        // The day is drawn above the first line said on it. Where the oldest
        // line held is not the oldest there is, nothing is claimed about it:
        // the line before it may well be from the same day.
        final bool startsTheDay = older == null
            ? !thread.hasEarlier
            : !_onOneDay(older.sentAt, line.sentAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (startsTheDay) MessageDay(line.sentAt.toLocal()),
            MessageBubble(
              message: line,
              isMine: line.senderUserId == thread.callerId,
              namesTheSender:
                  startsTheDay ||
                  older == null ||
                  older.senderUserId != line.senderUserId,
              wasRead: thread.thread.wasReadByAnother(line),
            ),
          ],
        );
      },
    );
  }

  static bool _onOneDay(DateTime one, DateTime other) {
    final DateTime first = one.toLocal();
    final DateTime second = other.toLocal();

    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

// What came before what is on the screen, asked for rather than taken: a
// thread that fetched itself as the reader scrolled could not be stopped.
class _Earlier extends StatelessWidget {
  const _Earlier(this.thread);

  final ThreadNotifier thread;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        children: <Widget>[
          if (thread.failureMessage case final String message) ...<Widget>[
            AppNotice(message),
            const SizedBox(height: AppSpacing.md),
          ],
          if (thread.isReadingEarlier)
            const SizedBox(
              width: AppSizes.spinner,
              height: AppSizes.spinner,
              child: CircularProgressIndicator(strokeWidth: AppSizes.stroke),
            )
          else if (thread.hasEarlier)
            OutlinedButton(
              onPressed: thread.readEarlier,
              child: Text(
                thread.failureMessage == null
                    ? 'Show earlier messages'
                    : 'Try again',
              ),
            ),
        ],
      ),
    );
  }
}
