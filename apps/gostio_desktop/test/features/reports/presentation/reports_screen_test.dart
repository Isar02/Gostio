import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/theme/app_theme.dart';
import 'package:gostio_desktop/features/listings/data/listing_address.dart';
import 'package:gostio_desktop/features/reports/data/report_scope.dart';
import 'package:gostio_desktop/features/reports/data/reports_repository.dart';
import 'package:gostio_desktop/features/reports/presentation/report_filters.dart';
import 'package:gostio_desktop/features/reports/presentation/reports_notifier.dart';
import 'package:gostio_desktop/features/reports/presentation/reports_screen.dart';
import 'package:provider/provider.dart';

import '../../../support/reports_double.dart';

void main() {
  testWidgets('the revenue document draws its months and their money', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(ReportsDouble()));
    await tester.pumpAndSettle();

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('4,710.25 KM'), findsNWidgets(2));
  });

  // The row under the rows is the server's own count, and it stands under the
  // columns it belongs to rather than beside them.
  testWidgets('the totals stand under the columns they count', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(ReportsDouble()));
    await tester.pumpAndSettle();

    expect(find.text('Total'), findsOneWidget);
    expect(find.text('9,420.50 KM'), findsOneWidget);
    expect(find.text('420.00 KM'), findsOneWidget);
  });

  testWidgets('the other document is read with the catalogue it covers', (
    WidgetTester tester,
  ) async {
    final ReportsDouble reports = ReportsDouble();
    await tester.pumpWidget(_screen(reports));
    await tester.pumpAndSettle();

    await tester.tap(find.text(ReportKind.revenue.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReportKind.listings.title).last);
    await tester.pumpAndSettle();

    expect(reports.targets.single, ListingKind.accommodation);
    expect(find.text('Nights'), findsOneWidget);
    expect(find.text('Sarajevo'), findsOneWidget);
    expect(find.text('Mostar'), findsOneWidget);
  });

  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(ReportsDouble(failing: true)));
    await tester.pumpAndSettle();

    expect(find.text('The report could not be built.'), findsOneWidget);
    expect(find.text('Trace b41c09'), findsOneWidget);
  });

  // Nothing to render is nothing to print, and both buttons say so by being
  // out of reach until a document is on screen.
  testWidgets('printing waits for a document to print', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(ReportsDouble(failing: true)));
    await tester.pumpAndSettle();

    expect(_enabled(tester, 'Print'), isFalse);
    expect(_enabled(tester, 'Save as PDF'), isFalse);
    expect(
      find.byTooltip('There is no report to save or print yet.'),
      findsNWidgets(2),
    );
  });

  // The dates say which of them is wrong; the table's place says only that
  // there is nothing to draw until they are answered.
  testWidgets('a range the server would refuse is said under its date', (
    WidgetTester tester,
  ) async {
    final ReportsDouble reports = ReportsDouble();
    await tester.pumpWidget(_screen(reports));
    await tester.pumpAndSettle();

    final ReportsNotifier notifier = tester
        .element(find.byType(ReportFilters))
        .read<ReportsNotifier>();
    await notifier.applyRange(notifier.range.endingOn(DateTime(2020, 1, 1)));
    await tester.pumpAndSettle();

    expect(reports.asked, 1);
    expect(find.text('A report cannot end before it starts.'), findsOneWidget);
    expect(find.text('Nothing to build yet'), findsOneWidget);
    expect(_enabled(tester, 'Print'), isFalse);
  });

  testWidgets('a document on screen is one both buttons can render', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(ReportsDouble()));
    await tester.pumpAndSettle();

    expect(_enabled(tester, 'Print'), isTrue);
    expect(_enabled(tester, 'Save as PDF'), isTrue);
  });
}

bool _enabled(WidgetTester tester, String label) => tester
    .widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (Widget widget) => widget is ButtonStyleButton,
        ),
      ),
    )
    .enabled;

// The window this client is built for is wide, and the filter bar is drawn as
// one row on it.
Widget _screen(ReportsDouble reports) => Provider<ReportsRepository>.value(
  value: reports,
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(
      body: SizedBox(
        width: 1440,
        height: 900,
        child: ReportsScreen(scope: ReportScope.platform),
      ),
    ),
  ),
);
