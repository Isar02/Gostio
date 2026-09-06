import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import 'booking_review_notifier.dart';
import 'review_sheet.dart';
import 'your_review.dart';

// The two actions available to the author of a review. The confirmation,
// refusal and edit sheet stay identical wherever the review is reached.
class ReviewOwnerActions extends StatefulWidget {
  const ReviewOwnerActions({
    required this.listingTitle,
    this.onTakenDown,
    super.key,
  });

  final String listingTitle;
  final VoidCallback? onTakenDown;

  @override
  State<ReviewOwnerActions> createState() => _ReviewOwnerActionsState();
}

class _ReviewOwnerActionsState extends State<ReviewOwnerActions> {
  String? _refusal;

  @override
  Widget build(BuildContext context) {
    final BookingReviewNotifier review = context.watch<BookingReviewNotifier>();
    final Review? written = review.review;

    if (written == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_refusal case final String refusal) ...<Widget>[
          AppNotice(refusal),
          const SizedBox(height: AppSpacing.md),
        ],
        YourReview(
          review: written,
          isBusy: review.isBusy,
          onEdit: () => unawaited(_edit()),
          onTakeDown: () => unawaited(_takeDown()),
        ),
      ],
    );
  }

  Future<void> _edit() {
    setState(() => _refusal = null);

    return ReviewSheet.show(context, listingTitle: widget.listingTitle);
  }

  Future<void> _takeDown() async {
    final BookingReviewNotifier review = context.read<BookingReviewNotifier>();
    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Take your review down?',
      message:
          'It stops being shown on ${widget.listingTitle}. You can write '
          'another one later.',
      confirmLabel: 'Take it down',
      cancelLabel: 'Keep it',
      isDestructive: true,
    );

    if (!agreed || !mounted) {
      return;
    }

    setState(() => _refusal = null);
    final bool removed = await review.takeDown();
    if (!mounted) {
      return;
    }

    if (removed) {
      widget.onTakenDown?.call();
    } else {
      setState(() => _refusal = review.failure?.message);
    }
  }
}
