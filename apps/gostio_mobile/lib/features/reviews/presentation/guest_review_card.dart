import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/rating_stars.dart';
import 'review_date_label.dart';

// One review in the list of what this account has written. The name on it is
// the reader's own, so the row leads with what the review is about.
class GuestReviewCard extends StatelessWidget {
  const GuestReviewCard(this.review, {this.onTap, super.key});

  final Review review;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      semanticLabel: _spoken,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            review.listingTitle,
            style: text.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.sm),
            Text(
              comment,
              style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  String get _spoken =>
      '${review.listingTitle}, ${review.rating} of ${ReviewStars.highest}, '
      '${reviewDateLabel(review)}';
}
