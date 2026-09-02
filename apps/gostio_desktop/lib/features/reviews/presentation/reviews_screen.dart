import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/tone.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/record_table.dart';
import '../../../core/widgets/screen_states.dart';
import '../../accommodations/data/accommodations_repository.dart';
import '../../experiences/data/experiences_repository.dart';
import '../data/review.dart';
import '../data/reviews_repository.dart';
import 'rating_stars.dart';
import 'review_dialog.dart';
import 'review_filter_options.dart';
import 'review_filters.dart';
import 'reviews_notifier.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  late final Future<ReviewFilterOptions> _options;

  @override
  void initState() {
    super.initState();
    _options = ReviewFilterOptions.load(
      context.read<AccommodationsRepository>(),
      context.read<ExperiencesRepository>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReviewsNotifier>(
      create: (BuildContext context) {
        final ReviewsNotifier reviews = ReviewsNotifier(
          context.read<ReviewsRepository>(),
        );
        unawaited(reviews.reload());

        return reviews;
      },
      child: _Body(options: _options),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.options});

  final Future<ReviewFilterOptions> options;

  @override
  Widget build(BuildContext context) {
    final ReviewsNotifier reviews = context.watch<ReviewsNotifier>();
    final String? failure = reviews.failureMessage;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (reviews.isStale) ...<Widget>[
            const AppNotice(_stale, tone: Tone.attention),
            const SizedBox(height: AppSpacing.md),
          ],
          FutureBuilder<ReviewFilterOptions>(
            future: options,
            builder: (
              BuildContext context,
              AsyncSnapshot<ReviewFilterOptions> snapshot,
            ) => _filters(snapshot, reviews),
          ),
          if (failure != null && reviews.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(failure),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.stroke,
            child: reviews.isLoading ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: RecordTable<Review>(
              columns: _columns,
              rows: reviews.items,
              onRowOpen: reviews.isStale
                  ? null
                  : (Review row) => _open(context, reviews, row),
              empty: _Nothing(reviews: reviews),
              footer: PaginationFooter(
                page: reviews.page,
                pageSize: reviews.pageSize,
                totalCount: reviews.totalCount,
                onPageChanged: reviews.openPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A listing list that did not arrive leaves its dropdown holding nothing.
  Widget _filters(
    AsyncSnapshot<ReviewFilterOptions> snapshot,
    ReviewsNotifier reviews,
  ) {
    final Widget filters = ReviewFilters(
      options: snapshot.data ?? ReviewFilterOptions.none,
      applied: reviews.query,
      isLoading: reviews.isLoading,
      onChanged: reviews.apply,
    );

    if (snapshot.error case final Object failure) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppNotice('The listings could not be read. $failure'),
          const SizedBox(height: AppSpacing.md),
          filters,
        ],
      );
    }

    return filters;
  }

  Future<void> _open(
    BuildContext context,
    ReviewsNotifier reviews,
    Review review,
  ) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String? said = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => ReviewDialog(
        review: review,
        takeDown: () => reviews.takeDown(review.reservationId),
      ),
    );

    if (said case final String message) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.reviews});

  final ReviewsNotifier reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isLoading) {
      return const LoadingState();
    }

    if (reviews.failureMessage case final String failure) {
      return ErrorState(
        message: failure,
        onRetry: reviews.reload,
        traceId: reviews.failureTraceId,
      );
    }

    return reviews.query.isEmpty
        ? const EmptyState(
            title: 'No reviews',
            message:
                'Guests write these once a booking is behind them. Nothing is '
                'written from this side.',
          )
        : const EmptyState(
            title: 'Nothing matches',
            message: 'No review answers every filter set above.',
          );
  }
}

// A stale list is read again before anything else is done to it.
const String _stale =
    'A review was taken down and the list could not be read again afterwards, '
    'so what stands here may be behind the server. Read it again before '
    'taking down another.';

const int _commentShare = 4;
const int _titleShare = 3;
const int _nameShare = 2;

final List<TableColumn<Review>> _columns = <TableColumn<Review>>[
  TableColumn<Review>.text(
    label: 'Guest',
    read: (Review row) => row.guestName,
    flex: _nameShare,
  ),
  TableColumn<Review>.text(
    label: 'Listing',
    read: (Review row) => row.listingTitle,
    flex: _titleShare,
  ),
  TableColumn<Review>(
    label: 'Rating',
    width: AppSizes.statusColumn,
    cell: (BuildContext context, Review row) => RatingStars(row.rating),
  ),
  TableColumn<Review>(
    label: 'Comment',
    flex: _commentShare,
    cell: (BuildContext context, Review row) => switch (row.comment) {
      final String comment => Text(comment),
      null => Text(
        'No comment',
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: AppColors.inkFaint),
      ),
    },
  ),
  TableColumn<Review>.text(
    label: 'Written',
    read: (Review row) => AppDates.date(row.createdAt),
    width: AppSizes.dateColumn,
  ),
  TableColumn<Review>.text(
    label: 'Edited',
    read: _editedOn,
    width: AppSizes.dateColumn,
  ),
];

String _editedOn(Review row) => switch (row.modifiedAt) {
  final DateTime edited => AppDates.date(edited),
  null => '—',
};
