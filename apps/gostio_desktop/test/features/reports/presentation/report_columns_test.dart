import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/reports/presentation/report_columns.dart';

import '../../../support/report_fixture.dart';

void main() {
  test('a month is read out under the headings the document carries', () {
    final List<RevenueColumn> columns = ReportColumns.revenue('bam');
    final RevenueReportRow row = revenueRow();

    expect(columns.map((RevenueColumn column) => column.label), <String>[
      'Month',
      'Bookings made',
      'Completed',
      'Charged',
      'Refunded',
      'Net',
    ]);
    expect(columns.map((RevenueColumn column) => column.cell(row)), <String>[
      'July 2026',
      '12',
      '9',
      '4,920.25 KM',
      '210.00 KM',
      '4,710.25 KM',
    ]);
  });

  // The totals are the server's own, so the row under the rows is read off
  // them rather than added up here.
  test('a total stands under the column it belongs to', () {
    final List<RevenueColumn> columns = ReportColumns.revenue('bam');
    final RevenueReportTotals totals = revenueReport().totals;

    expect(
      columns.map((RevenueColumn column) => column.total(totals)),
      <String>['Total', '24', '18', '9,840.50 KM', '420.00 KM', '9,420.50 KM'],
    );
  });

  // A processor configured for another currency answers one, and the document
  // prints what it was answered rather than the mark the product usually takes.
  test('money is printed in the currency the report was answered in', () {
    final RevenueColumn charged = ReportColumns.revenue('eur')[3];

    expect(charged.cell(revenueRow()), '4,920.25 EUR');
  });

  test('the column that counts what was sold is named after the catalogue', () {
    expect(
      ReportColumns.listings('bam', ListingKind.accommodation)[4].label,
      'Nights',
    );
    expect(
      ReportColumns.listings('bam', ListingKind.experience)[4].label,
      'Seats',
    );
  });

  test('a row nothing was reviewed in shows no score at all', () {
    final ListingColumn rating = ReportColumns.listings(
      'bam',
      ListingKind.accommodation,
    )[6];

    expect(rating.cell(listingRow()), '4.6');
    expect(rating.cell(listingRow(averageRating: null)), ReportColumns.nothing);
  });
}
