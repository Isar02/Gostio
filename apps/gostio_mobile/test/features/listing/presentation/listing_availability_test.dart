import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/listing/presentation/listing_availability.dart';

import '../../../support/auth_double.dart';
import '../../../support/listing_double.dart';
import '../../../support/listing_fixture.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  final DateTime thisMonth = CalendarDays.firstOfMonth(CalendarDays.today());
  final DateTime nextMonth = CalendarDays.addMonths(thisMonth, 1);

  // The calendar opens on the month it is read in, so the days it draws are
  // counted from today rather than written into the test.
  int dayAfterToday(int days) =>
      CalendarDays.addDays(CalendarDays.today(), days).day;

  Future<void> draw(WidgetTester tester, ListingDouble listings) async {
    await tester.pumpWidget(
      underTest(
        const Scaffold(body: ListingAvailability(1)),
        auth: AuthDouble(),
        listings: listings,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every night still on offer says what it costs', (
    WidgetTester tester,
  ) async {
    await draw(
      tester,
      ListingDouble(
        nights: monthOfNights(
          thisMonth,
          priced: <int, double>{dayAfterToday(2): 140},
        ),
      ),
    );

    expect(find.text('Availability'), findsOneWidget);
    expect(find.text('140'), findsOneWidget);
    expect(find.text('90'), findsWidgets);
  });

  // A night nobody may book any more is not priced: the figure under a day is
  // what it would cost to take it.
  testWidgets('a night that is gone is struck through and not priced', (
    WidgetTester tester,
  ) async {
    final int taken = dayAfterToday(3);

    await draw(
      tester,
      ListingDouble(nights: monthOfNights(thisMonth, taken: <int>{taken})),
    );

    expect(
      tester.widget<Text>(find.text('$taken')).style?.decoration,
      TextDecoration.lineThrough,
    );
  });

  testWidgets('a month already read is not asked for a second time', (
    WidgetTester tester,
  ) async {
    final ListingDouble listings = ListingDouble(
      nights: <StayCalendarDay>[
        ...monthOfNights(thisMonth),
        ...monthOfNights(nextMonth, price: 110),
      ],
    );

    await draw(tester, listings);
    expect(listings.monthsAsked, <DateTime>[thisMonth]);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('110'), findsWidgets);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();

    expect(listings.monthsAsked, <DateTime>[thisMonth, nextMonth]);
  });

  // A month already gone has no night left to sell.
  testWidgets('the calendar does not step back past the month it opens in', (
    WidgetTester tester,
  ) async {
    await draw(tester, ListingDouble(nights: monthOfNights(thisMonth)));

    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_left),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('a calendar that was refused is answered where it stands', (
    WidgetTester tester,
  ) async {
    await draw(
      tester,
      ListingDouble(
        calendarFailure: ApiException(
          message: 'The calendar could not be read.',
          statusCode: 500,
        ),
      ),
    );

    expect(find.text('The calendar could not be read.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  // A month drawn as six whole weeks is taller than six cells, because the
  // weekdays above them are a row of their own. Walking a year forward draws
  // every shape a month comes in, and an overflow in any of them fails here.
  testWidgets('no month is drawn into less room than it takes', (
    WidgetTester tester,
  ) async {
    await draw(tester, ListingDouble(nights: monthOfNights(thisMonth)));

    for (int month = 0; month < DateTime.monthsPerYear; month++) {
      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    }
  });
}
