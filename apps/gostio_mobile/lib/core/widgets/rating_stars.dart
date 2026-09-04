import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// A rating read at a glance and again in figures. A listing with no reviews
// yet says so rather than drawing five empty stars, which reads as nought.
class RatingStars extends StatelessWidget {
  const RatingStars({
    required this.rating,
    this.reviewCount,
    this.showFigure = true,
    super.key,
  });

  final double? rating;
  final int? reviewCount;
  final bool showFigure;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final double? rating = this.rating;

    if (rating == null || reviewCount == 0) {
      return Text(
        'No reviews yet',
        style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          label: '${AppNumbers.rating(rating)} out of ${ReviewStars.highest}',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final int star in ReviewStars.all)
                Icon(
                  _shapeAt(star, rating),
                  size: AppSizes.star,
                  color: AppColors.iris,
                ),
            ],
          ),
        ),
        if (showFigure) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Text(AppNumbers.rating(rating), style: text.labelMedium),
        ],
        if (reviewCount case final int count) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          Text(
            '($count)',
            style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ],
    );
  }

  // A star is filled once the rating reaches it, and half-filled while the
  // rating is inside it, so 4.5 is four and a half rather than five.
  static IconData _shapeAt(int star, double rating) {
    if (rating >= star) {
      return Icons.star_rounded;
    }

    return rating >= star - 0.5
        ? Icons.star_half_rounded
        : Icons.star_outline_rounded;
  }
}
