import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/paged_list.dart';
import 'listing_reviews_notifier.dart';
import 'review_card.dart';

// Everything written about one listing. It is drawn from the list the detail
// below it already read, so opening this asks the server for nothing that has
// already been answered and *Show more* carries on from where that page ended.
class ListingReviewsScreen extends StatelessWidget {
  const ListingReviewsScreen({
    required this.title,
    required this.emptyMessage,
    super.key,
  });

  static Future<void> open(
    BuildContext context, {
    required String title,
    required String emptyMessage,
  }) {
    final ListingReviewsNotifier reviews = context
        .read<ListingReviewsNotifier>();

    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            ChangeNotifierProvider<ListingReviewsNotifier>.value(
              // The list belongs to the screen underneath, which is what ends
              // it. This route borrows it and leaves it standing.
              value: reviews,
              child: ListingReviewsScreen(
                title: title,
                emptyMessage: emptyMessage,
              ),
            ),
      ),
    );
  }

  final String title;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Consumer<ListingReviewsNotifier>(
          builder:
              (
                BuildContext context,
                ListingReviewsNotifier reviews,
                Widget? _,
              ) => PagedList<Review>(
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
                emptyTitle: 'No reviews yet',
                emptyMessage: emptyMessage,
                itemBuilder: (BuildContext context, Review review) =>
                    ReviewCard(review),
              ),
        ),
      ),
    );
  }
}
