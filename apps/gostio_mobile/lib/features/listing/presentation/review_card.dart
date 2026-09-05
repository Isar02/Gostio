import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/rating_stars.dart';

// One review as it was left: who wrote it, when, what they gave and what they
// said. A review with no words is still a rating and is drawn as one.
class ReviewCard extends StatelessWidget {
  const ReviewCard(this.review, {super.key});

  final Review review;

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
                child: Text(
                  review.guestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                AppDates.date(review.createdAt),
                style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          RatingStars(rating: review.rating.toDouble(), showFigure: false),
          if (review.comment case final String comment) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(comment, style: text.bodyMedium),
          ],
          if (review.wasEdited) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text('Edited', style: text.labelSmall),
          ],
        ],
      ),
    );
  }
}
