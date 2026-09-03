import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/listings/data/listing_address.dart';
import 'package:gostio_desktop/features/reports/data/report_range.dart';
import 'package:gostio_desktop/features/reports/data/report_scope.dart';
import 'package:gostio_desktop/features/reports/presentation/report_printing.dart';
import 'package:gostio_desktop/features/reports/presentation/reports_notifier.dart';

import '../../../support/reports_double.dart';

void main() {
  final ReportRange summer = ReportRange(
    from: DateTime(2026, 1, 1),
    to: DateTime(2026, 8, 31),
  );

  Future<ReportsNotifier> opened(ReportScope scope) async {
    final ReportsNotifier reports = ReportsNotifier(
      ReportsDouble(),
      scope: scope,
    );
    await reports.applyRange(summer);

    return reports;
  }

  test('a saved revenue report is named by its scope and its range', () async {
    final ReportsNotifier reports = await opened(ReportScope.platform);

    expect(
      ReportPrinting.nameFor(reports),
      'gostio-platform-revenue-2026-01-01-2026-08-31.pdf',
    );
  });

  // Two documents saved into one folder differ by the scope they cover and, on
  // the listing report, by the catalogue as well.
  test('a saved listing report is named by the catalogue too', () async {
    final ReportsNotifier reports = await opened(ReportScope.mine);
    await reports.showReport(ReportKind.listings);
    await reports.applyCatalogue(ListingKind.experience);

    expect(
      ReportPrinting.nameFor(reports),
      'gostio-mine-listings-experiences-2026-01-01-2026-08-31.pdf',
    );
  });

  test('the same range under two scopes is two names', () async {
    final ReportsNotifier platform = await opened(ReportScope.platform);
    final ReportsNotifier mine = await opened(ReportScope.mine);

    expect(
      ReportPrinting.nameFor(platform),
      isNot(ReportPrinting.nameFor(mine)),
    );
  });
}
