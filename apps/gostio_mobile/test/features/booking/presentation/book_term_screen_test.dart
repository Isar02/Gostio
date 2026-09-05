import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/booking/presentation/book_term_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/booking_double.dart';
import '../../../support/booking_fixture.dart';
import '../../../support/listing_fixture.dart';
import '../../../support/payment_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  final DateTime morning = DateTime.utc(2026, 7, 14, 7);

  List<ExperienceSlot> threeTerms() => <ExperienceSlot>[
    experienceSlot(id: 1, startTime: morning, remainingCapacity: 6),
    experienceSlot(
      id: 2,
      startTime: morning.add(const Duration(days: 1)),
      remainingCapacity: 0,
    ),
    experienceSlot(
      id: 3,
      startTime: morning.add(const Duration(days: 2)),
      remainingCapacity: 2,
    ),
  ];

  Future<GlobalKey<NavigatorState>> open(
    WidgetTester tester,
    BookingDouble bookings,
  ) async {
    return pushOnto(
      tester,
      BookTermScreen(experience(title: 'Old town walk')),
      auth: AuthDouble(),
      bookings: bookings,
      payments: PaymentDouble(),
      cardSheet: CardSheetDouble(),
    );
  }

  testWidgets('the open terms say when they are and what each has left', (
    WidgetTester tester,
  ) async {
    await open(tester, BookingDouble(slots: threeTerms()));

    expect(find.text('Open terms'), findsOneWidget);
    expect(
      find.text('25.00 KM a person. Choose the one you want to come on.'),
      findsOneWidget,
    );
    expect(find.text('6 places left'), findsOneWidget);
    expect(find.text('2 places left'), findsOneWidget);
    expect(find.text('3 h'), findsNWidgets(3));
    expect(find.text('3 of 3 terms'), findsOneWidget);
  });

  // A term with nothing left cannot be taken, and neither can one this guest
  // already holds a place on. The two are different answers and are said apart.
  testWidgets('a full term and a term already held are both drawn as taken', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      BookingDouble(slots: threeTerms(), alreadyHeld: const <int>{3}),
    );

    expect(find.text('Full'), findsOneWidget);
    expect(find.text('Yours'), findsOneWidget);
    expect(find.text('2 places left'), findsNothing);
  });

  testWidgets('choosing a term prices it by the head', (
    WidgetTester tester,
  ) async {
    await open(tester, BookingDouble(slots: threeTerms()));

    expect(find.text('Choose a term'), findsOneWidget);

    await tester.tap(find.text('6 places left'));
    await tester.pumpAndSettle();

    expect(find.text('25.00 KM'), findsOneWidget);
    expect(find.text('1 guest at 25.00 KM'), findsOneWidget);

    await tester.tap(find.byTooltip('One more'));
    await tester.pumpAndSettle();

    expect(find.text('50.00 KM'), findsOneWidget);
  });

  // The party is held to what the term has left rather than sent and refused.
  testWidgets('the party stops at the places the term has left', (
    WidgetTester tester,
  ) async {
    await open(tester, BookingDouble(slots: threeTerms()));

    await tester.tap(find.text('2 places left'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('One more'));
    await tester.pumpAndSettle();

    expect(find.text('50.00 KM'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.add_rounded),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('the booking sends the term and the head count', (
    WidgetTester tester,
  ) async {
    final BookingDouble bookings = BookingDouble(
      slots: threeTerms(),
      made: termBooking(experienceSlotId: 1),
    );

    await open(tester, bookings);

    await tester.tap(find.text('6 places left'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();

    expect(bookings.termsBooked.single, (slotId: 1, guestCount: 1));
    expect(find.text('Your booking'), findsOneWidget);
  });

  // Another screen may open in this tab while the request is in flight. The
  // booking belongs in Trips then; its late answer must not replace the newer
  // screen merely because the form still exists underneath it.
  testWidgets('a late booking does not replace a newer screen', (
    WidgetTester tester,
  ) async {
    final BookingDouble bookings = BookingDouble(
      slots: threeTerms(),
      made: termBooking(experienceSlotId: 1),
      holdsTheCall: true,
    );
    final GlobalKey<NavigatorState> navigator = await open(tester, bookings);

    await tester.tap(find.text('6 places left'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book'));
    await tester.pump();

    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              const Scaffold(body: Center(child: Text('Newer screen'))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    bookings.answer();
    await tester.pumpAndSettle();

    expect(bookings.termsBooked, hasLength(1));
    expect(find.text('Newer screen'), findsOneWidget);
    expect(find.text('Your booking'), findsNothing);
  });

  testWidgets('a refusal is said beside the button that earned it', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      BookingDouble(
        slots: threeTerms(),
        failure: const ApiException(
          message: 'This term is full.',
          statusCode: 400,
        ),
      ),
    );

    await tester.tap(find.text('6 places left'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();

    expect(find.text('This term is full.'), findsOneWidget);
    expect(find.text('Your booking'), findsNothing);

    // The refusal was about the booking that was sent, and a booking for a
    // different party is not that one.
    await tester.tap(find.byTooltip('One more'));
    await tester.pumpAndSettle();

    expect(find.text('This term is full.'), findsNothing);
  });

  testWidgets('an experience with nothing left to book says so', (
    WidgetTester tester,
  ) async {
    await open(tester, BookingDouble());

    expect(find.text('No terms open'), findsOneWidget);
    expect(
      find.text('This experience has nothing left to book.'),
      findsOneWidget,
    );
  });
}
