import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/paged_list.dart';
import '../data/reviews_repository.dart';
import 'guest_review_card.dart';
import 'guest_review_screen.dart';
import 'guest_reviews_notifier.dart';

// What this account has written, reached from the profile. It is the same
// reviews the listings show, gathered by their author rather than by what
// they are about, so a guest can find one without remembering which trip it
// was against.
class GuestReviewsScreen extends StatelessWidget {
  const GuestReviewsScreen({required this.guestId, super.key});

  static Future<void> open(BuildContext context, int guestId) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              GuestReviewsScreen(guestId: guestId),
        ),
      );

  final int guestId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GuestReviewsNotifier>(
      create: (BuildContext context) =>
          GuestReviewsNotifier(context.read<ReviewsRepository>(), guestId),
      child: const _GuestReviews(),
    );
  }
}

class _GuestReviews extends StatelessWidget {
  const _GuestReviews();

  @override
  Widget build(BuildContext context) {
    final GuestReviewsNotifier reviews = context.watch<GuestReviewsNotifier>();

    return Scaffold(
      appBar: AppBar(title: const Text('Your reviews')),
      body: SafeArea(
        child: PagedList<Review>(
          items: reviews.items,
          totalCount: reviews.totalCount,
          noun: 'reviews',
          isLoading: reviews.isLoading,
          isAppending: reviews.isAppending,
          failureMessage: reviews.failureMessage,
          failureTraceId: reviews.failureTraceId,
          onMore: reviews.more,
          onRetry: reviews.retry,
          onRefresh: reviews.reload,
          emptyTitle: 'You have not written a review yet',
          emptyMessage:
              'A booking can be reviewed once it is behind you. Open it from '
              'Trips and say how it was.',
          itemBuilder: (BuildContext context, Review review) => GuestReviewCard(
            review,
            onTap: () => unawaited(
              GuestReviewScreen.open(
                context,
                review,
                onChanged: (Review? written) =>
                    reviews.changedFor(review.reservationId, written),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
