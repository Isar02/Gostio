import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/reports/data/report_range.dart';
import 'package:gostio_desktop/features/reports/data/report_scope.dart';
import 'package:gostio_desktop/features/reports/presentation/reports_notifier.dart';
import 'package:gostio_desktop/features/reports/presentation/shown_report.dart';

import '../../../support/reports_double.dart';

void main() {
  test('the screen opens on revenue over the rolling year to today', () async {
    final ReportsDouble reports = ReportsDouble();
    final ReportsNotifier notifier = ReportsNotifier(
      reports,
      scope: ReportScope.platform,
    );

    await notifier.reload();

    expect(notifier.kind, ReportKind.revenue);
    expect(notifier.revenue, isNotNull);
    expect(ShownReport.of(notifier), isNotNull);
    expect(reports.scopes.single, ReportScope.platform);
    expect(reports.revenueRanges.single, ReportRange.rollingYearToToday());
    expect(reports.listingRanges, isEmpty);
  });

  // A host asks the routes scoped to the caller; nothing in the request names
  // whose listings they are.
  test('a host reads the report family the panel is in', () async {
    final ReportsDouble reports = ReportsDouble();

    await ReportsNotifier(reports, scope: ReportScope.mine).reload();

    expect(reports.scopes.single, ReportScope.mine);
  });

  test(
    'a document already read over the range in force is not read twice',
    () async {
      final ReportsDouble reports = ReportsDouble();
      final ReportsNotifier notifier = ReportsNotifier(
        reports,
        scope: ReportScope.platform,
      );

      await notifier.reload();
      await notifier.showReport(ReportKind.listings);
      await notifier.showReport(ReportKind.revenue);
      await notifier.showReport(ReportKind.listings);

      expect(reports.revenueRanges, hasLength(1));
      expect(reports.listingRanges, hasLength(1));
    },
  );

  // A document read over dates that have since moved is not the one the
  // filters describe, so both are dropped and the one on screen is read again.
  test('a range that moves drops what was read under the old one', () async {
    final ReportsDouble reports = ReportsDouble();
    final ReportsNotifier notifier = ReportsNotifier(
      reports,
      scope: ReportScope.platform,
    );

    await notifier.reload();
    await notifier.showReport(ReportKind.listings);
    await notifier.applyRange(notifier.range.startingOn(DateTime(2026, 3, 1)));

    expect(notifier.revenue, isNull);
    expect(notifier.listings, isNotNull);
    expect(reports.listingRanges.last.from, DateTime(2026, 3, 1));

    await notifier.showReport(ReportKind.revenue);

    expect(reports.revenueRanges, hasLength(2));
    expect(reports.revenueRanges.last.from, DateTime(2026, 3, 1));
  });

  test('the catalogue is asked for only by the document it narrows', () async {
    final ReportsDouble reports = ReportsDouble();
    final ReportsNotifier notifier = ReportsNotifier(
      reports,
      scope: ReportScope.platform,
    );

    await notifier.reload();
    await notifier.applyCatalogue(ListingKind.experience);

    expect(reports.asked, 1);
    expect(notifier.catalogue, ListingKind.experience);

    await notifier.showReport(ReportKind.listings);

    expect(reports.targets.single, ListingKind.experience);

    await notifier.applyCatalogue(ListingKind.accommodation);

    expect(reports.targets, <ListingKind>[
      ListingKind.experience,
      ListingKind.accommodation,
    ]);
  });

  // The server answers the same refusal, and asking for one it would refuse is
  // a request made to be turned down.
  test('a range the server would refuse is never sent', () async {
    final ReportsDouble reports = ReportsDouble();
    final ReportsNotifier notifier = ReportsNotifier(
      reports,
      scope: ReportScope.platform,
    );

    await notifier.reload();
    await notifier.applyRange(notifier.range.endingOn(DateTime(2020, 1, 1)));

    expect(reports.asked, 1);
    expect(ShownReport.of(notifier), isNull);
    expect(notifier.range.refusal, 'A report cannot end before it starts.');
    expect(notifier.failureMessage, isNull);
  });

  test('a read that failed leaves no document and says why', () async {
    final ReportsNotifier notifier = ReportsNotifier(
      ReportsDouble(failing: true),
      scope: ReportScope.platform,
    );

    await notifier.reload();

    expect(ShownReport.of(notifier), isNull);
    expect(notifier.failureMessage, 'The report could not be built.');
    expect(notifier.failureTraceId, 'b41c09');
  });

  // A request made under dates that have since been changed to ones the server
  // would refuse is a request whose answer is about nothing on screen.
  test('an answer under dates since refused is not drawn', () async {
    final ReportsDouble reports = ReportsDouble(holds: true);
    final ReportsNotifier notifier = ReportsNotifier(
      reports,
      scope: ReportScope.platform,
    );

    final Future<void> asked = notifier.showReport(ReportKind.listings);
    await notifier.applyRange(notifier.range.endingOn(DateTime(2020, 1, 1)));
    await notifier.applyCatalogue(ListingKind.experience);

    reports.waits.single.complete();
    await asked;

    expect(reports.targets.single, ListingKind.accommodation);
    expect(notifier.catalogue, ListingKind.experience);
    expect(notifier.listings, isNull);
    expect(ShownReport.of(notifier), isNull);
  });

  test(
    'a cached document switch invalidates the document left in flight',
    () async {
      final ReportsDouble reports = ReportsDouble(holds: true);
      final ReportsNotifier notifier = ReportsNotifier(
        reports,
        scope: ReportScope.platform,
      );

      final Future<void> opening = notifier.reload();
      reports.waits.single.complete();
      await opening;

      final Future<void> oldListing = notifier.showReport(ReportKind.listings);
      await notifier.showReport(ReportKind.revenue);
      await notifier.applyCatalogue(ListingKind.experience);

      reports.waits[1].complete();
      await oldListing;

      expect(reports.targets.single, ListingKind.accommodation);
      expect(notifier.catalogue, ListingKind.experience);
      expect(notifier.listings, isNull);

      final Future<void> freshListing = notifier.showReport(
        ReportKind.listings,
      );

      expect(reports.targets.last, ListingKind.experience);

      reports.waits[2].complete();
      await freshListing;

      expect(ShownReport.of(notifier)?.title, contains('Experiences'));
    },
  );

  // Two ranges asked in a row and answered out of order: the older answer is
  // for a range nobody is looking at any more.
  test('an answer that was overtaken is not written', () async {
    final ReportsDouble reports = ReportsDouble(holds: true);
    final ReportsNotifier notifier = ReportsNotifier(
      reports,
      scope: ReportScope.platform,
    );

    final Future<void> first = notifier.reload();
    final Future<void> second = notifier.applyRange(
      notifier.range.startingOn(DateTime(2026, 5, 1)),
    );

    reports.waits.last.complete();
    await second;

    expect(ShownReport.of(notifier), isNotNull);
    expect(notifier.isLoading, isFalse);

    reports.waits.first.complete();
    await first;

    expect(ShownReport.of(notifier), isNotNull);
    expect(notifier.isLoading, isFalse);
  });
}
