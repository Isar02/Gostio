import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/rating_stars.dart';
import 'review_date_label.dart';

// A review as the guest who wrote it reads it: what they gave, what they said,
// when they said it, and the two things they may still do to it.
//
// The card on a listing draws the same review for everybody else and leads
// with the name of whoever left it. Here the name is the reader's own, so the
// space goes to the words instead.
class YourReview extends StatelessWidget {
  const YourReview({
    required this.review,
    required this.onEdit,
    required this.onTakeDown,
    this.isBusy = false,
    super.key,
  });

  final Review review;
  final VoidCallback onEdit;
  final VoidCallback onTakeDown;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: RatingStars(
                  rating: review.rating.toDouble(),
                  showFigure: false,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                reviewDateLabel(review),
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          if (review.comment case final String comment) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(comment, style: text.bodyMedium),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              // The ordinary action takes the width and the one that cannot be
              // undone takes only the words it needs, so the two are told
              // apart before either is read.
              Expanded(
                child: OutlinedButton(
                  onPressed: isBusy ? null : onEdit,
                  child: const Text('Edit'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              TextButton(
                style: _destructive,
                onPressed: isBusy ? null : onTakeDown,
                child: const Text('Take it down'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static final ButtonStyle _destructive = ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.disabled)
          ? AppColors.inkFaint
          : AppColors.danger,
    ),
  );
}
