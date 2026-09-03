import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/formatting/app_dates.dart';
import 'package:gostio_desktop/core/theme/app_theme.dart';
import 'package:gostio_desktop/features/overview/data/overview_month.dart';
import 'package:gostio_desktop/features/overview/presentation/overview_movements.dart';

import '../../../support/booking_fixture.dart';

void main() {
  // The day is read against today rather than printed as a date the reader has
  // to subtract; only the three days that have a word of their own get one.
  testWidgets('the near days are words and the rest are dates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _panel(<OverviewMovement>[
        _movement(DateTime(2026, 9, 3), -1),
        _movement(DateTime(2026, 9, 4), 0),
        _movement(DateTime(2026, 9, 5), 1),
        _movement(DateTime(2026, 9, 19), 15),
      ]),
    );

    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text(AppDates.day(DateTime(2026, 9, 19))), findsOneWidget);
  });

  testWidgets('a movement names its guest and the listing it is on', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _panel(<OverviewMovement>[_movement(DateTime(2026, 9, 4), 0)]),
    );

    expect(find.text('Ana Marić'), findsOneWidget);
    expect(find.text('Stone villa on the hill above Neum'), findsOneWidget);
  });

  testWidgets('a month nobody moves in says so in its own words', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_panel(const <OverviewMovement>[]));

    expect(find.text('Nothing to see off'), findsOneWidget);
    expect(find.text('Nobody checks out this month.'), findsOneWidget);
  });
}

OverviewMovement _movement(DateTime day, int daysAhead) =>
    OverviewMovement(booking: booking(), day: day, daysAhead: daysAhead);

Widget _panel(List<OverviewMovement> movements) => MaterialApp(
  theme: AppTheme.light,
  home: Scaffold(
    body: SizedBox(
      width: 480,
      height: 400,
      child: OverviewMovements(
        movements: movements,
        quiet: 'Nobody checks out this month.',
      ),
    ),
  ),
);
