import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/rating_stars.dart';
import '../data/listing_detail.dart';

// What the row says about itself: what it is called, where it is, how it has
// been rated, what it costs, who lets it and what they wrote about it.
//
// The figures are the server's and are only rendered. The words around them
// are worded here rather than in the data layer, because they are what this
// screen reads like rather than what the API answered.
class ListingSummary extends StatelessWidget {
  const ListingSummary(this.detail, {super.key});

  final ListingDetail detail;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(detail.title, style: text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          detail.place,
          style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        RatingStars(
          rating: detail.averageRating,
          reviewCount: detail.reviewCount,
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(AppNumbers.money(detail.price), style: text.titleLarge),
            const SizedBox(width: AppSpacing.sm),
            Text(
              detail.priceUnit,
              style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ],
        ),
        if (_extra case final String extra) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(extra, style: text.bodySmall),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(
          _facts.join(' · '),
          style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Divider(),
        const SizedBox(height: AppSpacing.lg),
        Text('Hosted by ${detail.hostName}', style: text.titleSmall),
        const SizedBox(height: AppSpacing.md),
        Text(detail.description, style: text.bodyMedium),
      ],
    );
  }

  // What each catalogue is worth saying in one line. A stay is described by
  // what is in it and a term by what happens on it, so the two lists share
  // nothing but the line they are drawn on.
  List<String> get _facts => switch (detail) {
    StayDetail(:final Accommodation stay) => <String>[
      stay.accommodationTypeName,
      stay.accommodationCategoryName,
      AppNumbers.counted(stay.maxGuests, 'guest'),
      AppNumbers.counted(stay.bedrooms, 'bedroom'),
      AppNumbers.counted(stay.bathrooms, 'bathroom'),
    ],
    ExperienceDetail(:final Experience experience) => <String>[
      experience.experienceCategoryName,
      AppDurations.inWords(experience.durationMinutes),
    ],
  };

  // The second figure a stay is priced by. It is charged once over the whole
  // booking rather than per night, so it is said beside the nightly rate
  // instead of being folded into it.
  String? get _extra => switch (detail) {
    StayDetail(:final Accommodation stay) when stay.cleaningFee > 0 =>
      'plus ${AppNumbers.money(stay.cleaningFee)} cleaning fee',
    _ => null,
  };
}
