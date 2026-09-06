import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/reviewed_trip_screen.dart';
import 'package:gostio_mobile/core/widgets/rating_input.dart';

import '../../../support/auth_double.dart';
import '../../../support/booking_fixture.dart';
import '../../../support/payment_double.dart';
import '../../../support/phone.dart';
import '../../../support/review_fixture.dart';
import '../../../support/reviews_double.dart';
import '../../../support/screens.dart';
import '../../../support/trips_double.dart';

// The review section under a booking that is behind the reader: writing one,
// changing it, and taking it back.
void main() {
  setUp(usePhoneScreen);

  Future<GlobalKey<NavigatorState>> open(
    WidgetTester tester,
    Reservation booking, {
    ReviewsDouble? reviews,
  }) => pushOnto(
    tester,
    ReviewedTripScreen(booking),
    auth: AuthDouble(),
    payments: PaymentDouble(),
    cardSheet: CardSheetDouble(),
    trips: TripsDouble(),
    reviews: reviews ?? ReviewsDouble(),
  );

  Reservation finished({int id = 501}) =>
      stayBooking(id: id, standing: ReservationStatus.completed, isPaid: true);

  Future<void> openTheSheet(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await tester.pumpAndSettle();
  }

  // The stars are the only controls inside the rating; the bar behind the
  // sheet and the cross above it are icon buttons too.
  Future<void> rate(WidgetTester tester, int stars) async {
    await tester.tap(
      find
          .descendant(
            of: find.byType(RatingInput),
            matching: find.byType(IconButton),
          )
          .at(stars - 1),
    );
    await tester.pumpAndSettle();
  }

  // A booking is reviewed once it is behind the guest, which is the server's
  // rule. A section that would only earn a refusal is not drawn, and nothing
  // is asked about a booking that cannot carry a review yet.
  testWidgets('a booking still ahead is asked nothing about a review', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble();
    await open(tester, stayBooking(), reviews: reviews);

    expect(find.text('Your review'), findsNothing);
    expect(reviews.read, isEmpty);
  });

  testWidgets('a finished booking nobody reviewed is invited to', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble();
    await open(tester, finished(), reviews: reviews);

    expect(reviews.read, <int>[501]);
    expect(find.text('How was it?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Write a review'), findsOneWidget);
  });

  testWidgets('a booking already reviewed draws what was written', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      finished(),
      reviews: ReviewsDouble(
        against: review(rating: 4, comment: 'Steep stairs, worth it.'),
      ),
    );

    expect(find.text('Steep stairs, worth it.'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Write a review'), findsNothing);
  });

  // A review is its rating. Words are the guest's to leave out, and what they
  // left out is sent as nothing rather than as an empty string.
  testWidgets('a review is posted with its rating and without words', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble();
    await open(tester, finished(), reviews: reviews);
    await openTheSheet(tester, 'Write a review');
    await rate(tester, 5);
    await tester.tap(find.widgetWithText(FilledButton, 'Post review'));
    await tester.pumpAndSettle();

    expect(reviews.posted.single.rating, 5);
    expect(reviews.posted.single.comment, isNull);
    expect(find.text('Post review'), findsNothing);
  });

  testWidgets('nothing is sent until a rating is given', (
    WidgetTester tester,
  ) async {
    await open(tester, finished());
    await openTheSheet(tester, 'Write a review');

    final FilledButton post = tester.widget(
      find.widgetWithText(FilledButton, 'Post review'),
    );

    expect(post.onPressed, isNull);
  });

  // A booking carries one review, so changing it is the same form and a
  // different call.
  testWidgets('a review already written is changed rather than repeated', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble(
      against: review(rating: 5, comment: 'Worth the stairs.'),
      answers: review(rating: 2, comment: 'Worth the stairs.'),
    );
    await open(tester, finished(), reviews: reviews);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(TextFormField, 'Worth the stairs.'),
      findsOneWidget,
      reason: 'the form opens on the review as it stands',
    );

    await rate(tester, 2);
    await tester.tap(find.widgetWithText(FilledButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(reviews.posted, isEmpty);
    expect(reviews.changed.single.rating, 2);
  });

  testWidgets('a refused review stays on the sheet in the server words', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      finished(),
      reviews: ReviewsDouble(
        writeFailure: const ApiException(
          message: 'This booking has already been reviewed.',
          statusCode: 400,
        ),
      ),
    );
    await openTheSheet(tester, 'Write a review');
    await rate(tester, 4);
    await tester.tap(find.widgetWithText(FilledButton, 'Post review'));
    await tester.pumpAndSettle();

    expect(
      find.text('This booking has already been reviewed.'),
      findsOneWidget,
    );
    expect(find.text('Post review'), findsOneWidget);
  });

  // Taking a review down cannot be undone, so it is asked about first and the
  // section draws what is left rather than what it had.
  testWidgets('a review is taken down only after it is agreed to', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble(against: review());
    await open(tester, finished(), reviews: reviews);
    await tester.tap(find.widgetWithText(TextButton, 'Take it down'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Keep it'));
    await tester.pumpAndSettle();

    expect(reviews.takenDown, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Take it down'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Take it down'));
    await tester.pumpAndSettle();

    expect(reviews.takenDown, <int>[501]);
    expect(find.widgetWithText(FilledButton, 'Write a review'), findsOneWidget);
  });

  // A read that was refused is not a booking with no review. Inviting one over
  // a refusal would offer a write the server may already hold a row for.
  testWidgets('a review that could not be read invites nothing', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      finished(),
      reviews: ReviewsDouble(
        readFailure: const ApiException(
          message: 'Your review could not be read.',
          statusCode: 500,
        ),
      ),
    );

    expect(find.text('Your review could not be read.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Write a review'), findsNothing);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets(
    'a review left half written is not discarded without a question',
    (WidgetTester tester) async {
      await open(tester, finished());
      await openTheSheet(tester, 'Write a review');
      await rate(tester, 3);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Leave this review?'), findsOneWidget);
    },
  );

  // The sheet sends the write and the section owns the answer. A reader who
  // leaves while it is in flight still has their review: the row goes to the
  // notifier the route holds rather than back through the surface that sent
  // it.
  testWidgets('a review that lands after the sheet was left still lands', (
    WidgetTester tester,
  ) async {
    final ReviewsDouble reviews = ReviewsDouble(
      holdsTheWrite: true,
      answers: review(rating: 4, comment: 'Steep stairs, worth it.'),
    );
    final GlobalKey<NavigatorState> navigator = await open(
      tester,
      finished(),
      reviews: reviews,
    );
    await openTheSheet(tester, 'Write a review');
    await rate(tester, 4);
    await tester.tap(find.widgetWithText(FilledButton, 'Post review'));
    await tester.pump();

    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    reviews.answerTheWrite();
    await tester.pumpAndSettle();

    expect(find.text('Steep stairs, worth it.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Write a review'), findsNothing);
  });
}
