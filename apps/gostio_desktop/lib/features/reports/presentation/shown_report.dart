import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../data/listing_report.dart';
import '../data/report_document.dart';
import '../data/revenue_report.dart';
import 'report_columns.dart';
import 'report_pdf.dart';
import 'report_table.dart';
import 'reports_notifier.dart';

// Which of the two reports is open is decided here and nowhere else, so the
// table and the printed page cannot describe different documents.
@immutable
class ShownReport<TRow, TTotals> {
  const ShownReport({
    required this.title,
    required this.document,
    required this.columns,
  });

  static ShownReport<Object?, Object?>? of(ReportsNotifier reports) => switch ((
    reports.kind,
    reports.revenue,
    reports.listings,
  )) {
    (ReportKind.revenue, final RevenueReport document, _) =>
      ShownReport<RevenueReportRow, RevenueReportTotals>(
        title: ReportKind.revenue.title,
        document: document,
        columns: ReportColumns.revenue(document.currency),
      ),
    (ReportKind.listings, _, final ListingReport document) =>
      ShownReport<ListingReportRow, ListingReportTotals>(
        title:
            '${ReportKind.listings.title}'
            ' · ${reports.catalogue.catalogueName}',
        document: document,
        columns: ReportColumns.listings(document.currency, reports.catalogue),
      ),
    _ => null,
  };

  final String title;
  final ReportDocument<TRow, TTotals> document;
  final List<ReportColumn<TRow, TTotals>> columns;

  Widget table({required Widget empty}) => ReportTable<TRow, TTotals>(
    document: document,
    columns: columns,
    empty: empty,
  );

  Future<Uint8List> printable({required String scope}) =>
      ReportPdf.build<TRow, TTotals>(
        title: title,
        scope: scope,
        document: document,
        columns: columns,
      );
}
