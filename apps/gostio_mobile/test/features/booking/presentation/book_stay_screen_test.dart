import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/calendar/date_range.dart';
import 'package:gostio_mobile/features/booking/presentation/book_stay_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/booking_double.dart';
import '../../../support/booking_fixture.dart';
import '../../../support/listing_double.dart';
import '../../../support/listing_fixture.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  // The month after the one the calendar opens on. Every day of it is ahead of
  // today whenever the suite is run, which the current month cannot promise.
  final DateTime month = CalendarDays.addMonths(
    CalendarDays.firstOfMonth(CalendarDays.today()),
    1,
  );

  DateTime dayOf(int day) => DateTime(month.year, month.month, day);

  // Pushed rather than drawn on its own, because leaving it is half of what
  // this screen has to answer for.
  Future<GlobalKey<NavigatorState>> open(
    WidgetTester tester, {
    required BookingDouble bookings,
    Set<int> taken = const <int>{},
    Map<int, double> priced = const <int, double>{},
  }) async {
    final GlobalKey<NavigatorState> navigator = await pushOnto(
      tester,
      BookStayScreen(stay(title: 'Loft over the river')),
      auth: AuthDouble(),
      listings: ListingDouble(
        nights: monthOfNights(month, taken: taken, priced: priced),
      ),
      bookings: bookings,
    );

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();

    return navigator;
  }

  Future<void> tapDay(WidgetTester tester, int day) async {
    await tester.tap(find.text('$day'));
    await tester.pumpAndSettle();
  }

  testWidgets('nothing is booked before a pair of dates is taken', (
    WidgetTester tester,
  ) async {
    await open(tester, bookings: BookingDouble());

    expect(find.text('Choose your dates'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('two taps price the stay from the nights it covers', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      bookings: BookingDouble(),
      priced: <int, double>{11: 140},
    );

    await tapDay(tester, 10);
    expect(find.textContaining('now choose the day you leave'), findsOneWidget);

    await tapDay(tester, 13);

    // What is being agreed to stays beside the button rather than scrolling
    // away above it.
    expect(find.text('335.00 KM'), findsOneWidget);
    expect(find.text('3 nights · 1 guest'), findsOneWidget);

    // Ninety, a hundred and forty, ninety, and the fee charged once over them.
    await tester.scrollUntilVisible(find.text('Cleaning fee'), 300);
    await tester.pumpAndSettle();

    expect(find.text('3 nights'), findsOneWidget);
    expect(find.text('320.00 KM'), findsOneWidget);
    expect(find.text('15.00 KM'), findsOneWidget);
    expect(find.text('335.00 KM'), findsNWidgets(2));
  });

  // A stay occupies the nights up to the day it ends on, so a range that would
  // cover a night somebody else holds is not one this screen offers to send.
  testWidgets('a range is not taken across a night that is gone', (
    WidgetTester tester,
  ) async {
    await open(tester, bookings: BookingDouble(), taken: <int>{11});

    await tapDay(tester, 10);
    await tapDay(tester, 13);

    expect(find.text('Choose your dates'), findsOneWidget);
  });

  testWidgets('the booking sends the nights and the head count', (
    WidgetTester tester,
  ) async {
    final BookingDouble bookings = BookingDouble(made: stayBooking());

    await open(tester, bookings: bookings);

    await tapDay(tester, 10);
    await tapDay(tester, 13);
    await tester.tap(find.byTooltip('One more'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();

    expect(bookings.staysBooked.single, (
      accommodationId: 1,
      dates: DateRange(from: dayOf(10), to: dayOf(13)),
      guestCount: 2,
    ));
    expect(find.text('Your booking'), findsOneWidget);
  });

  testWidgets('a refusal is said on the screen and opens nothing', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      bookings: BookingDouble(
        failure: const ApiException(
          message: 'Part of these dates is already booked.',
          statusCode: 400,
        ),
      ),
    );

    await tapDay(tester, 10);
    await tapDay(tester, 13);
    await tester.tap(find.text('Book'));
    await tester.pumpAndSettle();

    expect(find.text('Part of these dates is already booked.'), findsOneWidget);
    expect(find.text('Your booking'), findsNothing);

    // The refusal was about the dates that were sent. Taking different ones
    // leaves it standing over a booking it was never answered about.
    await tapDay(tester, 18);

    expect(find.text('Part of these dates is already booked.'), findsNothing);
  });

  // A party the reader stepped up is something they put there, and Back asks
  // before it goes.
  testWidgets('a party changed on its own is not discarded without asking', (
    WidgetTester tester,
  ) async {
    await open(tester, bookings: BookingDouble());

    await tester.tap(find.byTooltip('One more'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Leave this booking?'), findsOneWidget);
  });

  // The navigator the form was pushed into outlives the form, so a late answer
  // measured against it would land the booking's screen on whatever replaced
  // the form.
  testWidgets('a booking that lands after the form was left opens nothing', (
    WidgetTester tester,
  ) async {
    final BookingDouble bookings = BookingDouble(holdsTheCall: true);
    final GlobalKey<NavigatorState> navigator = await open(
      tester,
      bookings: bookings,
    );

    await tapDay(tester, 10);
    await tapDay(tester, 13);
    await tester.tap(find.text('Book'));
    await tester.pump();

    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    bookings.answer();
    await tester.pumpAndSettle();

    expect(bookings.staysBooked, hasLength(1));
    expect(find.text('Your booking'), findsNothing);
  });

  // The party is bounded by what the place sleeps rather than sent and refused.
  testWidgets('the party stops at what the place sleeps', (
    WidgetTester tester,
  ) async {
    await open(tester, bookings: BookingDouble());

    for (int step = 0; step < 3; step++) {
      await tester.tap(find.byTooltip('One more'));
      await tester.pumpAndSettle();
    }

    expect(find.text('This place sleeps 4.'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.add_rounded),
          )
          .onPressed,
      isNull,
    );
  });
}
