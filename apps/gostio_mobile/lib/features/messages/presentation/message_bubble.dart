import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';

// One line of a thread. Which side it is on says who said it, so the name is
// drawn only where a run of lines starts and only for the other party.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    required this.namesTheSender,
    required this.wasRead,
    super.key,
  });

  final Message message;
  final bool isMine;
  final bool namesTheSender;

  // Whether somebody else in the thread has seen it, which is only worth
  // saying about a line the reader sent.
  final bool wasRead;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: _spoken,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.only(
          top: namesTheSender ? AppSpacing.md : AppSpacing.xs,
          left: isMine ? AppSpacing.xxl : 0,
          right: isMine ? 0 : AppSpacing.xxl,
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: <Widget>[
            if (namesTheSender && !isMine) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  bottom: AppSpacing.xs,
                ),
                child: Text(
                  message.senderName,
                  style: text.labelMedium?.copyWith(color: AppColors.inkMuted),
                ),
              ),
            ],
            _Words(message: message, isMine: isMine),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                _said,
                style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _said => isMine && wasRead
      ? '${AppDates.time(message.sentAt)} · Read'
      : AppDates.time(message.sentAt);

  String get _spoken => <String>[
    isMine ? 'You' : message.senderName,
    message.body,
    _said,
  ].join('. ');
}

class _Words extends StatelessWidget {
  const _Words({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isMine ? AppColors.indigo : AppColors.surface,
        border: isMine
            ? null
            : const Border.fromBorderSide(
                BorderSide(color: AppColors.border, width: AppSizes.hairline),
              ),
        // The corner nearest the speaker is drawn tighter, so a run of lines
        // reads as one side talking rather than as a column of equal boxes.
        borderRadius: BorderRadius.only(
          topLeft: AppRadii.large.topLeft,
          topRight: AppRadii.large.topRight,
          bottomLeft: isMine
              ? AppRadii.large.bottomLeft
              : AppRadii.small.topLeft,
          bottomRight: isMine
              ? AppRadii.small.topLeft
              : AppRadii.large.bottomRight,
        ),
      ),
      child: SelectableText(
        message.body,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: isMine ? AppColors.surface : AppColors.ink),
      ),
    );
  }
}

// The day a run of lines was said on, drawn once above the first of them.
class MessageDay extends StatelessWidget {
  const MessageDay(this.day, {super.key});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: const BoxDecoration(
            color: AppColors.neutralGround,
            borderRadius: AppRadii.pill,
          ),
          child: Text(
            AppDates.date(day),
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.neutral),
          ),
        ),
      ),
    );
  }
}
