import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/formatting/app_dates.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/core/theme/app_theme.dart';
import 'package:gostio_desktop/core/time/calendar_days.dart';
import 'package:gostio_desktop/features/overview/data/overview_repository.dart';
import 'package:gostio_desktop/features/overview/presentation/host_overview_screen.dart';
import 'package:gostio_desktop/features/overview/presentation/overview_figures.dart';
import 'package:gostio_desktop/features/overview/presentation/overview_movements.dart';
import 'package:gostio_desktop/features/overview/presentation/overview_timeline.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';
import 'package:provider/provider.dart';

import '../../../support/booking_fixture.dart';
import '../../../support/overview_doubles.dart';
import '../../../support/overview_fixture.dart';

void main() {
  testWidgets('the four figures the host is asked about are drawn', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          figures: hostOverview(
            accommodations: 3,
            experiences: 2,
            bookingsThisMonth: 18,
            netThisMonth: 3240,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_figure(tester, '3'), findsOneWidget);
    expect(_figure(tester, '2'), findsOneWidget);
    expect(_figure(tester, '18'), findsOneWidget);
    expect(_figure(tester, '3,240.00 KM'), findsOneWidget);
  });

  testWidgets('the month is headed by its own name and its nights', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(OverviewDouble(bookings: _stay())));
    await tester.pumpAndSettle();

    expect(find.text(AppDates.month(CalendarDays.today())), findsOneWidget);
    expect(find.text('4 nights booked'), findsOneWidget);
  });

  testWidgets('a listing is a row and the stay on it is a bar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(OverviewDouble(bookings: _stay())));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(OverviewTimeline),
        matching: find.text('Stone villa on the hill above Neum'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(OverviewTimeline),
        matching: find.text('Emir Hodžić'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('who arrives and who leaves are each their own panel', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(OverviewDouble(bookings: _stay())));
    await tester.pumpAndSettle();

    expect(find.text('Arrivals'), findsOneWidget);
    expect(find.text('Departures'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(OverviewMovements),
        matching: find.text('Emir Hodžić'),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('a host with nothing to let is told so where the month goes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(OverviewDouble(listings: const <LookupItem>[])),
    );
    await tester.pumpAndSettle();

    expect(find.text('No listing to fill yet'), findsOneWidget);
    expect(find.text('Nobody checks in this month.'), findsOneWidget);
  });

  // A read that failed leaves nothing to read around, so the whole screen says
  // so rather than three panels each saying it separately.
  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          failing: const ApiException(
            message: 'The month could not be read.',
            traceId: 'd90a17',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The month could not be read.'), findsOneWidget);
    expect(find.text('Trace d90a17'), findsOneWidget);
    expect(find.byType(OverviewTimeline), findsNothing);
  });

  testWidgets('the month steps back and forth from the one in force', (
    WidgetTester tester,
  ) async {
    final OverviewDouble overview = OverviewDouble();
    await tester.pumpWidget(_screen(overview));
    await tester.pumpAndSettle();

    expect(find.text('This month'), findsNothing);

    await tester.tap(find.byTooltip('The month after'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        AppDates.month(CalendarDays.addMonths(CalendarDays.today(), 1)),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();

    expect(find.text(AppDates.month(CalendarDays.today())), findsOneWidget);
    expect(overview.months, hasLength(3));
  });
}

Finder _figure(WidgetTester tester, String value) => find.descendant(
  of: find.byType(OverviewFigures),
  matching: find.text(value),
);

// Four nights inside the month whichever month the clock is in, so the figures
// the screen prints do not move with the day the test is run on.
List<Reservation> _stay() {
  final DateTime tenth = CalendarDays.addDays(
    CalendarDays.firstOfMonth(CalendarDays.today()),
    9,
  );

  return <Reservation>[
    booking(
      accommodationId: 4,
      reservationStatusId: 2,
      status: 'Confirmed',
      guestName: 'Emir Hodžić',
      checkInDate: tenth,
      checkOutDate: CalendarDays.addDays(tenth, 4),
    ),
  ];
}

Widget _screen(OverviewDouble overview) => Provider<OverviewRepository>.value(
  value: overview,
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(
      body: SizedBox(
        width: 1440,
        height: 900,
        child: HostOverviewScreen(hostId: 7),
      ),
    ),
  ),
);
