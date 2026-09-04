import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/paging/writing_notifier.dart';
import 'package:gostio_desktop/features/reviews/data/review_query.dart';
import 'package:gostio_desktop/features/reviews/presentation/reviews_notifier.dart';

import '../../../support/review_fixture.dart';
import '../../../support/reviews_double.dart';

void main() {
  test('a band of ratings is applied from the first page', () async {
    final ReviewsDouble reviews = _reviews(totalCount: 60);
    final ReviewsNotifier notifier = _notifier(reviews);

    await notifier.openPage(3);
    await notifier.apply(const ReviewQuery(lowestRating: 4));

    expect(notifier.page, 1);
    expect(reviews.pages, <int>[3, 1]);
    expect(reviews.queries.last.toParameters(), <String, dynamic>{
      'minRating': 4,
    });
  });

  // Nothing is written here, so the page the row stood on is the page to come
  // back to rather than the first one.
  test(
    'a review is taken down through its booking, on the page it was on',
    () async {
      final ReviewsDouble reviews = _reviews(totalCount: 60);
      final ReviewsNotifier notifier = _notifier(reviews);

      await notifier.openPage(2);
      final WriteOutcome outcome = await notifier.takeDown(31);

      expect(outcome.wasWritten, isTrue);
      expect(outcome.viewSettled, isTrue);
      expect(reviews.takenDown, <int>[31]);
      expect(reviews.pages, <int>[2, 2]);
      expect(notifier.isWriting, isFalse);
    },
  );

  // The dialog is what stays open and says so, so the refusal is handed back
  // rather than left on the list, and the rows are not read again for it.
  test(
    'a refused take-down comes back to the caller and reads nothing',
    () async {
      final ReviewsDouble reviews = _reviews(
        refusing: const ApiException(
          message: 'A review is the guest\'s to take back.',
          statusCode: 403,
        ),
      );
      final ReviewsNotifier notifier = _notifier(reviews);

      await notifier.reload();
      final WriteOutcome outcome = await notifier.takeDown(31);

      expect(
        outcome.refusal?.message,
        'A review is the guest\'s to take back.',
      );
      expect(reviews.takenDown, isEmpty);
      expect(reviews.pages, hasLength(1));
      expect(notifier.failureMessage, isNull);
      expect(notifier.isStale, isFalse);
    },
  );

  // The review went and the read after it did not, so the rows on screen are
  // behind the server until a read lands.
  test(
    'a take-down whose read failed leaves the rows behind the server',
    () async {
      final _ReadsOnce reviews = _ReadsOnce();
      final ReviewsNotifier notifier = _notifier(reviews);

      await notifier.reload();
      final WriteOutcome outcome = await notifier.takeDown(31);

      expect(outcome.wasWritten, isTrue);
      expect(outcome.viewSettled, isFalse);
      expect(notifier.isStale, isTrue);
      expect(notifier.failureMessage, 'The reviews could not be read.');

      reviews.answers = true;
      await notifier.reload();

      expect(notifier.isStale, isFalse);
    },
  );

  test('a review names the catalogue its booking was against', () {
    expect(review().listingKind, ListingKind.accommodation);
    expect(
      review(accommodationId: null, experienceId: 12).listingKind,
      ListingKind.experience,
    );
  });
}

class _ReadsOnce extends ReviewsDouble {
  _ReadsOnce() : super(rows: <Review>[review()]);

  bool answers = true;

  @override
  Future<PagedResult<Review>> search({
    required ReviewQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) {
    if (answers) {
      answers = false;

      return super.search(query: query, page: page, pageSize: pageSize);
    }

    throw const ApiException(message: 'The reviews could not be read.');
  }
}

ReviewsDouble _reviews({int? totalCount, ApiException? refusing}) =>
    ReviewsDouble(
      rows: <Review>[review()],
      totalCount: totalCount,
      refusing: refusing,
    );

ReviewsNotifier _notifier(ReviewsDouble reviews) {
  final ReviewsNotifier notifier = ReviewsNotifier(reviews);
  addTearDown(notifier.dispose);

  return notifier;
}
