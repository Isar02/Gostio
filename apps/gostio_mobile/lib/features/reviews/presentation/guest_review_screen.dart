import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../data/reviews_repository.dart';
import 'booking_review_notifier.dart';
import 'review_owner_actions.dart';

// One review the reader has written, opened from the list of them. It is the
// same two things the trip screen offers — changing it and taking it back —
// on the surface a guest reaches them from when the booking itself is not
// what they are looking for.
//
// The route owns the write. A review taken down or changed here is handed to
// the list behind whether or not this screen is still open.
class GuestReviewScreen extends StatelessWidget {
  const GuestReviewScreen(this.review, {this.onChanged, super.key});

  static Future<void> open(
    BuildContext context,
    Review review, {
    ValueChanged<Review?>? onChanged,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          GuestReviewScreen(review, onChanged: onChanged),
    ),
  );

  final Review review;
  final ValueChanged<Review?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BookingReviewNotifier>(
      create: (BuildContext context) => BookingReviewNotifier(
        context.read<ReviewsRepository>(),
        review.reservationId,
        review: review,
        onChanged: onChanged,
      ),
      child: _WrittenReview(review.listingTitle),
    );
  }
}

class _WrittenReview extends StatelessWidget {
  const _WrittenReview(this.listingTitle);

  final String listingTitle;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Your review')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Text(listingTitle, style: text.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            ReviewOwnerActions(
              listingTitle: listingTitle,
              // The write outlives this screen, so what it answers has already
              // reached the list behind. Leaving is this route's own business
              // and only happens where the reader has not gone somewhere else.
              onTakenDown: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
