import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodations_repository.dart';
import 'package:gostio_desktop/features/experiences/data/experiences_repository.dart';
import 'package:gostio_desktop/features/reviews/data/review.dart';
import 'package:gostio_desktop/features/reviews/data/review_query.dart';
import 'package:gostio_desktop/features/reviews/data/reviews_repository.dart';
import 'package:gostio_desktop/features/reviews/presentation/rating_stars.dart';
import 'package:gostio_desktop/features/reviews/presentation/reviews_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/catalogue_doubles.dart';
import '../../../support/review_fixture.dart';
import '../../../support/reviews_double.dart';

void main() {
  testWidgets('a review is drawn by who wrote it, what it was for and how it '
      'was rated', (WidgetTester tester) async {
    await tester.pumpWidget(_screen(ReviewsDouble(rows: <Review>[review()])));
    await tester.pumpAndSettle();

    expect(find.text('Ana Marić'), findsOneWidget);
    expect(find.text('Stone villa on the hill above Neum'), findsOneWidget);
    expect(
      find.text('The terrace over the bay was worth the drive.'),
      findsOneWidget,
    );
    expect(tester.widget<RatingStars>(find.byType(RatingStars)).rating, 5);
  });

  // A rating may be left without a word beside it, which is a cell with
  // nothing in it rather than a column that failed to draw.
  testWidgets('a rating left without words says so', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(ReviewsDouble(rows: <Review>[review(comment: null)])),
    );
    await tester.pumpAndSettle();

    expect(find.text('No comment'), findsOneWidget);
  });

  testWidgets('nothing to read names the side these are written from', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(ReviewsDouble()));
    await tester.pumpAndSettle();

    expect(find.text('No reviews'), findsOneWidget);
  });

  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(ReviewsDouble(failing: true)));
    await tester.pumpAndSettle();

    expect(find.text('The reviews could not be read.'), findsOneWidget);
    expect(find.text('Trace 4b91ec'), findsOneWidget);
  });

  testWidgets('a row opens on a double click and is taken down from there', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble(rows: <Review>[review()]);
    await tester.pumpWidget(_screen(reviews));
    await tester.pumpAndSettle();

    await _openTheRow(tester, 'Ana Marić');

    expect(find.text('Accommodation'), findsOneWidget);

    await tester.tap(find.text('Take down'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Take down'));
    await tester.pumpAndSettle();

    expect(reviews.takenDown, <int>[31]);
    expect(find.text('The review was taken down.'), findsOneWidget);
  });

  // What the server refused stays in the dialog, where the review it is about
  // is still on screen.
  testWidgets('a refused take-down is said in the dialog it was asked from', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        ReviewsDouble(
          rows: <Review>[review()],
          refusing: const ApiException(
            message: 'A review is the guest\'s to take back.',
            statusCode: 403,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _openTheRow(tester, 'Ana Marić');
    await tester.tap(find.text('Take down'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Take down'));
    await tester.pumpAndSettle();

    expect(find.text('A review is the guest\'s to take back.'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  // What the server refuses is said in the dialog, so the dialog cannot be
  // clicked away while the take-down it would say it in is still in flight.
  testWidgets('a take-down in flight holds the dialog it was asked from', (
    WidgetTester tester,
  ) async {
    final _Holds reviews = _Holds();
    await tester.pumpWidget(_screen(reviews));
    await tester.pumpAndSettle();

    await _openTheRow(tester, 'Ana Marić');
    await tester.tap(find.text('Take down'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Take down'));
    await tester.pump();

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(find.text('Taking down'), findsOneWidget);

    reviews.refuse();
    await tester.pumpAndSettle();

    expect(find.text('That could not be done.'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  // The take-down landed and the read after it did not, so the rows on screen
  // are behind the server and none of them opens.
  testWidgets('a take-down whose read failed shuts the list and says so', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_ReadsOnce()));
    await tester.pumpAndSettle();

    await _openTheRow(tester, 'Ana Marić');
    await tester.tap(find.text('Take down'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Take down'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('could not be read again afterwards'),
      findsOneWidget,
    );
    expect(
      find.text('The review was taken down. The list could not be read again.'),
      findsOneWidget,
    );

    await _openTheRow(tester, 'Ana Marić');

    expect(find.text('Take down'), findsNothing);
  });
}

// Held open so a test can stand in the moment a take-down is still running.
class _Holds extends ReviewsDouble {
  _Holds() : super(rows: <Review>[review()]);

  final Completer<void> _writing = Completer<void>();

  void refuse() => _writing.completeError(
    const ApiException(message: 'That could not be done.', statusCode: 500),
  );

  @override
  Future<void> takeDown(int reservationId) => _writing.future;
}

class _ReadsOnce extends ReviewsDouble {
  _ReadsOnce() : super(rows: <Review>[review()]);

  @override
  Future<PagedResult<Review>> search({
    required ReviewQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) {
    if (pages.isEmpty) {
      return super.search(query: query, page: page, pageSize: pageSize);
    }

    pages.add(page);

    throw const ApiException(message: 'The reviews could not be read.');
  }
}

Widget _screen(ReviewsDouble reviews) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<ReviewsRepository>.value(value: reviews),
    Provider<AccommodationsRepository>.value(value: StaysDouble()),
    Provider<ExperiencesRepository>.value(value: TermsDouble()),
  ],
  child: const MaterialApp(home: Scaffold(body: ReviewsScreen())),
);

Future<void> _openTheRow(WidgetTester tester, String name) async {
  final Finder row = find.text(name).first;

  await tester.tap(row);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(row);
  await tester.pumpAndSettle();
}
