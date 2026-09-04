import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/core/theme/app_colors.dart';
import 'package:gostio_desktop/core/theme/app_theme.dart';
import 'package:gostio_desktop/core/time/calendar_days.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application.dart';
import 'package:gostio_desktop/features/overview/data/destination_share.dart';
import 'package:gostio_desktop/features/overview/data/overview_repository.dart';
import 'package:gostio_desktop/features/overview/presentation/overview_bookings.dart';
import 'package:gostio_desktop/features/overview/presentation/overview_figures.dart';
import 'package:gostio_desktop/features/overview/presentation/overview_ranking.dart';
import 'package:gostio_desktop/features/overview/presentation/overview_trend.dart';
import 'package:gostio_desktop/features/overview/presentation/platform_overview_screen.dart';
import 'package:gostio_desktop/features/reports/data/revenue_report.dart';
import 'package:provider/provider.dart';

import '../../../support/application_fixture.dart';
import '../../../support/overview_doubles.dart';
import '../../../support/overview_fixture.dart';
import '../../../support/report_fixture.dart';

void main() {
  testWidgets('the four figures the platform is read by are drawn', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          standing: platformOverview(
            users: 1247,
            listings: 312,
            bookingsThisMonth: 489,
            netThisMonth: 24580,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_figure('1247'), findsOneWidget);
    expect(_figure('312'), findsOneWidget);
    expect(_figure('489'), findsOneWidget);
    expect(_figure('24,580.00 KM'), findsOneWidget);
  });

  testWidgets('the year draws a bar to a month and names them', (
    WidgetTester tester,
  ) async {
    final DateTime today = CalendarDays.today();
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          standing: platformOverview(
            trade: <RevenueReportRow>[
              revenueRow(year: today.year, month: today.month, net: 8400),
              revenueRow(year: today.year, month: 1, net: 2100),
              revenueRow(year: today.year, month: 2, net: 0),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OverviewTrend), findsOneWidget);
    expect(find.text('Jan'), findsOneWidget);
    expect(find.text('Feb'), findsOneWidget);
  });

  // A year in which every month is exactly nought has no length to draw with,
  // so it says so instead of dividing by a span of nought.
  testWidgets('a year that traded nothing draws no bars', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          standing: platformOverview(
            trade: <RevenueReportRow>[revenueRow(net: 0), revenueRow(net: 0)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing traded yet'), findsOneWidget);
    expect(_bars(AppColors.iris), findsNothing);
  });

  // A month that gave back more than it took is a net below nought. It is
  // drawn under the line rather than folded up above it, where it would read
  // as a small month that earned something.
  testWidgets('a month that gave more back than it took is drawn as a loss', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          standing: platformOverview(
            trade: <RevenueReportRow>[
              revenueRow(month: 6, net: 4200),
              revenueRow(month: 7, net: -800, refunded: 800, grossCharged: 0),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing traded yet'), findsNothing);
    expect(_bars(AppColors.iris), findsOneWidget);
    expect(_bars(AppColors.danger), findsOneWidget);
  });

  // A year that only ever gave money back has a length to draw with, and it
  // is all below the line.
  testWidgets('a year of nothing but refunds is still drawn', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          standing: platformOverview(
            trade: <RevenueReportRow>[
              revenueRow(month: 6, net: -300, refunded: 300, grossCharged: 0),
              revenueRow(month: 7, net: -900, refunded: 900, grossCharged: 0),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nothing traded yet'), findsNothing);
    expect(_bars(AppColors.danger), findsNWidgets(2));
    expect(_bars(AppColors.iris), findsNothing);
  });

  testWidgets('the destinations are ranked with what each took', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          standing: platformOverview(
            destinations: const <DestinationShare>[
              DestinationShare(
                city: 'Mostar',
                bookings: 9,
                grossCharged: 3120.50,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(OverviewRanking),
        matching: find.text('Mostar'),
      ),
      findsOneWidget,
    );
    expect(find.text('3,120.50 KM'), findsOneWidget);
  });

  testWidgets('a booking keeps the word and the colour the table gives it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(OverviewDouble(standing: platformOverview())),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(OverviewBookings),
        matching: find.text('Pending'),
      ),
      findsOneWidget,
    );
    expect(find.text('760.00 KM'), findsOneWidget);
  });

  // The few shown are not necessarily all there are.
  testWidgets('the waiting queue says how many are waiting in all', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          standing: platformOverview(
            waiting: <HostApplication>[application()],
            waitingCount: 14,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Waiting to host'), findsOneWidget);
    expect(find.text('14 waiting in all'), findsOneWidget);
    expect(find.text('Ana Kovač'), findsOneWidget);
  });

  testWidgets('a queue that is empty is answered rather than left blank', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          standing: platformOverview(
            waiting: const <HostApplication>[],
            waitingCount: 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nobody is waiting'), findsOneWidget);
    expect(find.text('0 waiting in all'), findsNothing);
  });

  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        OverviewDouble(
          standing: platformOverview(),
          failing: const ApiException(
            message: 'The platform could not be read.',
            traceId: 'a51b30',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The platform could not be read.'), findsOneWidget);
    expect(find.text('Trace a51b30'), findsOneWidget);
  });
}

// A bar is the only painted box the trend draws, so its colour is what tells
// a month that earned from one that gave back.
Finder _bars(Color ink) => find.descendant(
  of: find.byType(OverviewTrend),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).color == ink,
  ),
);

Finder _figure(String value) => find.descendant(
  of: find.byType(OverviewFigures),
  matching: find.text(value),
);

Widget _screen(OverviewDouble overview) => Provider<OverviewRepository>.value(
  value: overview,
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(
      body: SizedBox(width: 1440, height: 900, child: PlatformOverviewScreen()),
    ),
  ),
);
