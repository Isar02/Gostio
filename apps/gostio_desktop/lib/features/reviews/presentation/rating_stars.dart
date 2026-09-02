import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../data/review_stars.dart';

class RatingStars extends StatelessWidget {
  const RatingStars(this.rating, {this.size = AppSizes.iconSmall, super.key});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$rating out of ${ReviewStars.highest}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // The build subsets the icon font by the glyphs it can see named,
          // so each mark names its own rather than picking at runtime.
          for (final int star in ReviewStars.all)
            if (star <= rating)
              Icon(Icons.star, size: size, color: AppColors.indigo)
            else
              Icon(
                Icons.star_outline,
                size: size,
                color: AppColors.borderStrong,
              ),
        ],
      ),
    );
  }
}
