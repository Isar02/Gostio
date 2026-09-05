import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/section_header.dart';
import '../data/listing_detail.dart';
import 'listing_reviews_notifier.dart';
import 'listing_reviews_screen.dart';
import 'review_card.dart';

// The top of what has been written about this listing. The rest is a screen of
// its own rather than a longer section: a page of reviews inside a page that
// already scrolls is two lists fighting over one gesture.
class ListingReviews extends StatelessWidget {
  const ListingReviews(this.detail, {super.key});

  // The listing these belong to: what the screen behind them is called, and
  // which of the two catalogues is being reviewed.
  final ListingDetail detail;

  static const int _shown = 3;

  @override
  Widget build(BuildContext context) {
    return Consumer<ListingReviewsNotifier>(
      builder:
          (BuildContext context, ListingReviewsNotifier reviews, Widget? _) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SectionHeader(
                    'Reviews',
                    actionLabel: reviews.totalCount > _shown
                        ? 'See all ${reviews.totalCount}'
                        : null,
                    onAction: () => ListingReviewsScreen.open(
                      context,
                      title: detail.title,
                      emptyMessage: _nothingWritten,
                    ),
                  ),
                  _body(reviews),
                ],
              ),
    );
  }

  Widget _body(ListingReviewsNotifier reviews) {
    if (reviews.items.isEmpty) {
      if (reviews.isLoading) {
        return const LoadingState();
      }

      if (reviews.failureMessage case final String message) {
        return AppNotice(message);
      }

      return EmptyState(title: 'No reviews yet', message: _nothingWritten);
    }

    return Column(
      children: <Widget>[
        for (final Review review in reviews.items.take(_shown))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ReviewCard(review),
          ),
      ],
    );
  }

  // A review is left against a booking that was paid for, and the two
  // catalogues are not booked in the same words.
  String get _nothingWritten => switch (detail) {
    StayDetail() => 'A review is written after a stay has been paid for.',
    ExperienceDetail() =>
      'A review is written after an experience has been paid for.',
  };
}
