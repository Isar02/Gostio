import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/section_header.dart';
import 'booking_review_notifier.dart';
import 'review_owner_actions.dart';
import 'review_sheet.dart';

// What the guest said about a booking that is behind them, under the booking
// itself. A booking is reviewed once it is over, so this is drawn only where
// the server would take one.
//
// The review is read here rather than with the booking: a reader who never
// opens a finished trip should not have paid for the read, and a booking that
// cannot be reviewed never asks at all.
class BookingReview extends StatefulWidget {
  const BookingReview({required this.listingTitle, super.key});

  final String listingTitle;

  @override
  State<BookingReview> createState() => _BookingReviewState();
}

class _BookingReviewState extends State<BookingReview> {
  @override
  void initState() {
    super.initState();

    // Asked after the frame that mounts this rather than during it: a notifier
    // that published from inside initState would be dirtying the tree it is
    // being built into.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        unawaited(context.read<BookingReviewNotifier>().readOnce());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final BookingReviewNotifier review = context.watch<BookingReviewNotifier>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader('Your review'),
        _body(context, review),
      ],
    );
  }

  Widget _body(BuildContext context, BookingReviewNotifier review) {
    if (review.isReading) {
      return Text(
        'Reading your review.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: AppColors.inkFaint),
      );
    }

    // A read that was refused says so rather than inviting a review the
    // server may already hold one of.
    if (review.readFailure case final String message) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppNotice(message, tone: Tone.attention),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => unawaited(review.readOnce()),
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    if (review.review case final Review written) {
      return ReviewOwnerActions(
        key: ValueKey<int>(written.id),
        listingTitle: widget.listingTitle,
      );
    }

    return review.hasRead
        ? _Invitation(onWrite: () => _write(context))
        : const SizedBox.shrink();
  }

  Future<void> _write(BuildContext context) {
    return ReviewSheet.show(context, listingTitle: widget.listingTitle);
  }
}

class _Invitation extends StatelessWidget {
  const _Invitation({required this.onWrite});

  final Future<void> Function() onWrite;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('How was it?', style: text.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your rating is what the next guest reads first.',
            style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: () => unawaited(onWrite()),
            child: const Text('Write a review'),
          ),
        ],
      ),
    );
  }
}
