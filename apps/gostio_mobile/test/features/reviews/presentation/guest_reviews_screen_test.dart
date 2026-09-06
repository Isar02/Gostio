import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/reviews/presentation/guest_review_card.dart';
import 'package:gostio_mobile/features/reviews/presentation/guest_reviews_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/phone.dart';
import '../../../support/review_fixture.dart';
import '../../../support/reviews_double.dart';
import '../../../support/screens.dart';

// The reviews this account has written, reached from the profile, and the one
// of them a reader opens to change or take back.
void main() {
  setUp(usePhoneScreen);

  Future<void> open(WidgetTester tester, ReviewsDouble reviews) => pushOnto(
    tester,
    const GuestReviewsScreen(guestId: 12),
    auth: AuthDouble(),
    reviews: reviews,
  );

  Future<void> openTheFirst(WidgetTester tester) async {
    await tester.tap(find.byType(GuestReviewCard).first);
    await tester.pumpAndSettle();
  }

  Future<void> takeItDown(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Take it down'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Take it down'));
    await tester.pumpAndSettle();
  }

  testWidgets('the list says what each review is about and how much of it', (
    WidgetTester tester,
  ) async {
    await open(tester, ReviewsDouble(written: reviews(3)));

    expect(find.byType(GuestReviewCard), findsNWidgets(3));
    expect(find.text('Listing 1'), findsOneWidget);
    expect(find.text('3 of 3 reviews'), findsOneWidget);
  });

  testWidgets('an account that has written nothing is told where one starts', (
    WidgetTester tester,
  ) async {
    await open(tester, ReviewsDouble());

    expect(find.text('You have not written a review yet'), findsOneWidget);
  });

  testWidgets('one review is opened on its own with what can be done to it', (
    WidgetTester tester,
  ) async {
    await open(tester, ReviewsDouble(written: <Review>[review()]));
    await openTheFirst(tester);

    expect(find.text('Your review'), findsOneWidget);
    expect(find.text('Loft over the river'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Edit'), findsOneWidget);
  });

  // The screen that took it down leaves with it, and the list behind is one
  // row and one row of the whole shorter without being read again.
  testWidgets('a review taken down leaves the screen and the list', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble(
      written: <Review>[review(), review(id: 92, reservationId: 502)],
    );
    await open(tester, reviews);
    await openTheFirst(tester);
    await takeItDown(tester);

    expect(reviews.takenDown, <int>[501]);
    expect(reviews.pagesAsked, <int>[1]);
    expect(find.byType(GuestReviewCard), findsOneWidget);
    expect(find.text('1 of 1 reviews'), findsOneWidget);
  });

  // What the write answered goes to the list rather than being carried back by
  // the sheet, so the row behind agrees without the list being read again.
  testWidgets('a review changed on its screen comes back to its card', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble(
      written: <Review>[review(rating: 5, comment: 'Worth the stairs.')],
      answers: review(rating: 2, comment: 'The boiler gave up.'),
    );
    await open(tester, reviews);
    await openTheFirst(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(reviews.pagesAsked, <int>[1]);
    expect(find.text('The boiler gave up.'), findsOneWidget);
  });
}
