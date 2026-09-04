import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/account_avatar.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.isMine,
    required this.namesTheSender,
    required this.hasPicture,
    required this.wasRead,
    super.key,
  });

  final Message message;
  final bool isMine;

  final bool namesTheSender;

  final bool hasPicture;
  final bool wasRead;

  @override
  Widget build(BuildContext context) {
    final Widget said = Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: <Widget>[
        if (namesTheSender && !isMine)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              message.senderName,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        _Words(message: message, isMine: isMine),
        _Said(message: message, wasRead: wasRead),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
        top: namesTheSender ? AppSpacing.md : AppSpacing.xs,
        left: isMine ? AppSpacing.xxl : 0,
        right: isMine ? 0 : AppSpacing.xxl,
      ),
      child: isMine
          ? said
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: AppSizes.avatar,
                  child: namesTheSender
                      ? AccountAvatar(
                          userId: message.senderUserId,
                          name: message.senderName,
                          hasImage: hasPicture,
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(child: said),
              ],
            ),
    );
  }
}

class _Words extends StatelessWidget {
  const _Words({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AppSizes.bubble),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.indigo : AppColors.hover,
          border: isMine
              ? null
              : Border.all(color: AppColors.border, width: AppSizes.hairline),
          // The squared corner points at whoever is speaking.
          borderRadius: BorderRadius.only(
            topLeft: AppRadii.large.topLeft,
            topRight: AppRadii.large.topRight,
            bottomLeft: isMine
                ? AppRadii.large.bottomLeft
                : AppRadii.smallRadius,
            bottomRight: isMine
                ? AppRadii.smallRadius
                : AppRadii.large.bottomRight,
          ),
        ),
        child: SelectableText(
          message.body,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: isMine ? AppColors.surface : AppColors.ink),
        ),
      ),
    );
  }
}

class _Said extends StatelessWidget {
  const _Said({required this.message, required this.wasRead});

  final Message message;
  final bool wasRead;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xs,
        left: AppSpacing.md,
        right: AppSpacing.md,
      ),
      child: Tooltip(
        message: AppDates.dateTime(message.sentAt),
        child: Text(
          wasRead
              ? '${AppDates.time(message.sentAt)} · Read'
              : AppDates.time(message.sentAt),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.inkFaint),
        ),
      ),
    );
  }
}

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
