import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import 'conversation_look.dart';
import 'message_bubble.dart';
import 'message_composer.dart';
import 'thread_notifier.dart';

class ThreadView extends StatelessWidget {
  const ThreadView({required this.thread, required this.callerId, super.key});

  static const Duration grouped = Duration(minutes: 10);

  static const String _bodyField = 'body';

  final Conversation thread;
  final int callerId;

  @override
  Widget build(BuildContext context) {
    final ThreadNotifier lines = context.watch<ThreadNotifier>();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border, width: AppSizes.hairline),
      ),
      child: Column(
        children: <Widget>[
          _Header(
            thread: thread,
            callerId: callerId,
            isLive: lines.isLive,
            lostLive: lines.liveFailureMessage,
          ),
          if (lines.failureMessage case final String failure)
            if (lines.lines.isNotEmpty) _Aside(child: AppNotice(failure)),
          Expanded(
            child: _Lines(thread: thread, callerId: callerId),
          ),
          if (lines.sendFailureMessage case final String refusal)
            _Aside(child: AppNotice(refusal)),
          if (!thread.joinedBy(callerId))
            const _Aside(
              child: AppNotice(
                'Nobody from this side has answered yet. Sending puts this '
                'account in the thread; until then what was said in it keeps '
                'counting as unread.',
                tone: Tone.informative,
              ),
            ),
          MessageComposer(
            hint: thread.type == ConversationType.support
                ? 'Answer the request'
                : 'Write a reply',
            isSending: lines.isSending,
            refusal: lines.messageFor(_bodyField),
            onSend: lines.send,
          ),
        ],
      ),
    );
  }
}

class _Aside extends StatelessWidget {
  const _Aside({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: child,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.thread,
    required this.callerId,
    required this.isLive,
    required this.lostLive,
  });

  final Conversation thread;
  final int callerId;
  final bool isLive;
  final String? lostLive;

  String get _about => switch (thread.type) {
    ConversationType.support => 'A request written to support',
    _ when thread.isAboutABooking =>
      'About the booking of ${thread.listingTitle ?? 'a listing'}',
    _ => 'An enquiry, with no booking behind it',
  };

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final List<ConversationParticipant> others = thread.othersThan(callerId);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.hover,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: AppSizes.hairline),
        ),
      ),
      child: Row(
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
              children: <Widget>[
                Text(
                  thread.withWhom(callerId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                Text(
                  _about,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          StatusChip(thread.type.label, tone: thread.type.tone),
          const SizedBox(width: AppSpacing.md),
          _Keeping(isLive: isLive, lostLive: lostLive),
        ],
      ),
    );
  }
}

class _Keeping extends StatelessWidget {
  const _Keeping({required this.isLive, required this.lostLive});

  final bool isLive;
  final String? lostLive;

  String get _how => isLive
      ? 'The hub is carrying this thread, so a message arrives as it is '
            'written.'
      : 'The hub is not carrying this thread, so it reads itself again every '
            '${ThreadNotifier.refreshInterval.inSeconds} seconds.';

  @override
  Widget build(BuildContext context) {
    final Tone tone = isLive ? Tone.positive : Tone.attention;

    return Tooltip(
      message: switch (lostLive) {
        final String reason when !isLive => '$_how\n\n$reason',
        _ => _how,
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: AppSizes.dot,
            height: AppSizes.dot,
            decoration: BoxDecoration(
              color: tone.foreground,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            isLive ? 'Live' : 'Refreshing',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: tone.foreground),
          ),
        ],
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.thread, required this.callerId});

  final Conversation thread;
  final int callerId;

  @override
  Widget build(BuildContext context) {
    final ThreadNotifier lines = context.watch<ThreadNotifier>();

    if (lines.lines.isEmpty) {
      if (lines.isLoading) {
        return const LoadingState();
      }

      if (lines.failureMessage case final String failure) {
        return ErrorState(
          message: failure,
          onRetry: lines.open,
          traceId: lines.failureTraceId,
        );
      }

      return const EmptyState(
        title: 'Nothing said yet',
        message: 'This thread was opened and left. Write the first message.',
      );
    }

    // Drawn from the newest end, so a long thread opens where it is being read.
    return ListView(
      reverse: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      children: _drawn(lines).reversed.toList(growable: false),
    );
  }

  List<Widget> _drawn(ThreadNotifier lines) {
    final List<Widget> drawn = <Widget>[];
    final Message? mineLast = _lastOfMine(lines.lines);

    DateTime? day;
    Message? said;

    for (final Message line in lines.lines) {
      final DateTime on = _dayOf(line.sentAt);
      if (day != on) {
        drawn.add(MessageDay(on));
        day = on;
      }

      drawn.add(
        MessageBubble(
          message: line,
          isMine: line.senderUserId == callerId,
          namesTheSender:
              said == null ||
              said.senderUserId != line.senderUserId ||
              line.sentAt.difference(said.sentAt) > ThreadView.grouped,
          hasPicture: _hasPicture(line.senderUserId),
          wasRead: identical(line, mineLast) && thread.wasReadByAnother(line),
        ),
      );

      said = line;
    }

    if (lines.hasEarlier) {
      drawn.insert(
        0,
        _Earlier(isReading: lines.isReadingEarlier, onRead: lines.readEarlier),
      );
    }

    return drawn;
  }

  bool _hasPicture(int userId) => thread.participants.any(
    (ConversationParticipant one) =>
        one.userId == userId && one.hasProfileImage,
  );

  Message? _lastOfMine(List<Message> lines) {
    for (var at = lines.length - 1; at >= 0; at--) {
      if (lines[at].senderUserId == callerId) {
        return lines[at];
      }
    }

    return null;
  }

  static DateTime _dayOf(DateTime moment) {
    final DateTime here = moment.toLocal();

    return DateTime(here.year, here.month, here.day);
  }
}

// A thread is paged from its newest end, so the pages after the first are what
// came before.
class _Earlier extends StatelessWidget {
  const _Earlier({required this.isReading, required this.onRead});

  final bool isReading;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: isReading
            ? const SizedBox(
                width: AppSizes.spinner,
                height: AppSizes.spinner,
                child: CircularProgressIndicator(strokeWidth: AppSizes.stroke),
              )
            : TextButton(
                onPressed: onRead,
                child: const Text('Read what came before'),
              ),
      ),
    );
  }
}
