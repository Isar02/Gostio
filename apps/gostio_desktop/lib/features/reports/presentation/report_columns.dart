import 'package:flutter/foundation.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/formatting/app_numbers.dart';
import '../../listings/data/listing_address.dart';
import '../data/listing_report.dart';
import '../data/revenue_report.dart';

// A heading, what a row says under it and what the totals row says, held
// together so a total cannot end up under the wrong column.
@immutable
class ReportColumn<TRow, TTotals> {
  const ReportColumn({
    required this.label,
    required this.cell,
    required this.total,
    this.flex = 1,
    this.numeric = false,
  });

  final String label;
  final String Function(TRow row) cell;
  final String Function(TTotals totals) total;
  final int flex;
  final bool numeric;
}

typedef RevenueColumn = ReportColumn<RevenueReportRow, RevenueReportTotals>;
typedef ListingColumn = ReportColumn<ListingReportRow, ListingReportTotals>;

abstract final class ReportColumns {
  static const String nothing = '—';

  static List<RevenueColumn> revenue(String currency) => <RevenueColumn>[
    RevenueColumn(
      label: 'Month',
      cell: (RevenueReportRow row) => AppDates.month(row.monthStart),
      total: (RevenueReportTotals totals) => 'Total',
      flex: _wide,
    ),
    RevenueColumn(
      label: 'Bookings made',
      cell: (RevenueReportRow row) => '${row.bookingsCreated}',
      total: (RevenueReportTotals totals) => '${totals.bookingsCreated}',
      numeric: true,
    ),
    RevenueColumn(
      label: 'Completed',
      cell: (RevenueReportRow row) => '${row.bookingsCompleted}',
      total: (RevenueReportTotals totals) => '${totals.bookingsCompleted}',
      numeric: true,
    ),
    RevenueColumn(
      label: 'Charged',
      cell: (RevenueReportRow row) =>
          AppNumbers.moneyIn(row.grossCharged, currency),
      total: (RevenueReportTotals totals) =>
          AppNumbers.moneyIn(totals.grossCharged, currency),
      numeric: true,
      flex: _wide,
    ),
    RevenueColumn(
      label: 'Refunded',
      cell: (RevenueReportRow row) =>
          AppNumbers.moneyIn(row.refunded, currency),
      total: (RevenueReportTotals totals) =>
          AppNumbers.moneyIn(totals.refunded, currency),
      numeric: true,
      flex: _wide,
    ),
    RevenueColumn(
      label: 'Net',
      cell: (RevenueReportRow row) => AppNumbers.moneyIn(row.net, currency),
      total: (RevenueReportTotals totals) =>
          AppNumbers.moneyIn(totals.net, currency),
      numeric: true,
      flex: _wide,
    ),
  ];

  // A stay sells nights and a term sells seats.
  static List<ListingColumn> listings(String currency, ListingKind target) =>
      <ListingColumn>[
        ListingColumn(
          label: 'City',
          cell: (ListingReportRow row) => row.city,
          total: (ListingReportTotals totals) => 'Total',
          flex: _wide,
        ),
        ListingColumn(
          label: 'Category',
          cell: (ListingReportRow row) => row.category,
          total: (ListingReportTotals totals) => '',
          flex: _wide,
        ),
        ListingColumn(
          label: 'Published',
          cell: (ListingReportRow row) => '${row.listingsPublished}',
          total: (ListingReportTotals totals) => '${totals.listingsPublished}',
          numeric: true,
        ),
        ListingColumn(
          label: 'Bookings',
          cell: (ListingReportRow row) => '${row.bookings}',
          total: (ListingReportTotals totals) => '${totals.bookings}',
          numeric: true,
        ),
        ListingColumn(
          label: switch (target) {
            ListingKind.accommodation => 'Nights',
            ListingKind.experience => 'Seats',
          },
          cell: (ListingReportRow row) => '${row.unitsSold}',
          total: (ListingReportTotals totals) => '${totals.unitsSold}',
          numeric: true,
        ),
        ListingColumn(
          label: 'Charged',
          cell: (ListingReportRow row) =>
              AppNumbers.moneyIn(row.grossCharged, currency),
          total: (ListingReportTotals totals) =>
              AppNumbers.moneyIn(totals.grossCharged, currency),
          numeric: true,
          flex: _wide,
        ),
        ListingColumn(
          label: 'Rating',
          cell: (ListingReportRow row) => _rating(row.averageRating),
          total: (ListingReportTotals totals) => _rating(totals.averageRating),
          numeric: true,
        ),
        ListingColumn(
          label: 'Reviews',
          cell: (ListingReportRow row) => '${row.reviewCount}',
          total: (ListingReportTotals totals) => '${totals.reviewCount}',
          numeric: true,
        ),
      ];

  // Nothing reviewed is not a score of nought.
  static String _rating(double? value) =>
      value == null ? nothing : AppNumbers.rating(value);

  static const int _wide = 2;
}
