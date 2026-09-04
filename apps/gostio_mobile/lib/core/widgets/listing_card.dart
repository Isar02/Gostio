import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';
import 'api_image.dart';
import 'app_card.dart';
import 'rating_stars.dart';
import 'status_chip.dart';

// One row of either catalogue. It takes what it draws rather than a model,
// because a stay and an experience are different rows of the same shape and
// neither belongs to this layer.
//
// The API answers a cover as an address, never as bytes, so the picture
// arrives after the card. The card is laid out to be right before it does.
class ListingCard extends StatelessWidget {
  const ListingCard({
    required this.title,
    required this.place,
    required this.price,
    this.priceUnit,
    this.coverPath,
    this.rating,
    this.reviewCount,
    this.status,
    this.statusTone = Tone.neutral,
    this.onTap,
    super.key,
  });

  final String title;
  final String place;
  final double price;
  final String? priceUnit;
  final String? coverPath;
  final double? rating;
  final int? reviewCount;
  final String? status;
  final Tone statusTone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      semanticLabel: _spoken,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              AspectRatio(
                aspectRatio: AppSizes.coverAspect,
                child: ApiImage(
                  path: coverPath,
                  borderRadius: BorderRadius.zero,
                  width: double.infinity,
                ),
              ),
              if (status case final String status)
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  child: StatusChip(status, tone: statusTone),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  place,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                RatingStars(rating: rating, reviewCount: reviewCount),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Text(AppNumbers.money(price), style: text.titleSmall),
                    if (priceUnit case final String unit) ...<Widget>[
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        unit,
                        style: text.bodySmall?.copyWith(
                          color: AppColors.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // The card is one thing, and this is it said once rather than as the four
  // fragments it is drawn from.
  String get _spoken {
    final StringBuffer spoken = StringBuffer('$title, $place');

    if (rating case final double rating when reviewCount != 0) {
      spoken.write(', rated ${AppNumbers.rating(rating)}');
      if (reviewCount case final int count) {
        spoken.write(' from $count ${count == 1 ? "review" : "reviews"}');
      }
    } else {
      spoken.write(', no reviews yet');
    }

    spoken.write(', ${AppNumbers.money(price)}');
    if (priceUnit case final String unit) {
      spoken.write(' $unit');
    }

    if (status case final String status) {
      spoken.write(', $status');
    }

    return spoken.toString();
  }
}
