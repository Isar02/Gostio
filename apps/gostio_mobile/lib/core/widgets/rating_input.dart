import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// The rating side of a review, set with a thumb. `RatingStars` reads one and
// this writes one: the five stars there are drawn at a glance, and the five
// here are controls and are measured for a thumb.
//
// Nothing is chosen until the reader chooses it. A form that opened on three
// stars would collect three from everybody who left the rating alone, so the
// value starts as none and the button that sends it waits for one.
class RatingInput extends StatelessWidget {
  const RatingInput({
    required this.rating,
    required this.onChanged,
    this.label = 'Your rating',
    super.key,
  });

  final int? rating;
  final ValueChanged<int> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: text.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            for (final int star in ReviewStars.all)
              _Star(
                star: star,
                isFilled: rating != null && star <= rating!,
                onPressed: () => onChanged(star),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _means,
          style: text.bodySmall?.copyWith(
            color: rating == null ? AppColors.inkFaint : AppColors.inkMuted,
          ),
        ),
      ],
    );
  }

  // A figure a reader has to translate into an opinion is a figure they can
  // get wrong, so each one says what it means in this product's own words.
  String get _means => switch (rating) {
    1 => 'Poor',
    2 => 'Fair',
    3 => 'Good',
    4 => 'Very good',
    5 => 'Excellent',
    _ => 'Tap a star to rate what you booked.',
  };
}

class _Star extends StatelessWidget {
  const _Star({
    required this.star,
    required this.isFilled,
    required this.onPressed,
  });

  final int star;
  final bool isFilled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: '$star of ${ReviewStars.highest}',
      iconSize: AppSizes.icon,
      constraints: const BoxConstraints.tightFor(
        width: AppSizes.touchTarget,
        height: AppSizes.touchTarget,
      ),
      icon: Icon(
        isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
        color: isFilled ? AppColors.iris : AppColors.borderStrong,
      ),
    );
  }
}
