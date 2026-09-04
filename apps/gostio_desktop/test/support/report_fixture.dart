import 'package:gostio_core/gostio_core.dart';

// Two months of trade and two rows of the catalogue, in the shape the API
// answers with. What a test is about it says itself.
RevenueReport revenueReport({
  List<RevenueReportRow>? rows,
  RevenueReportTotals? totals,
}) => RevenueReport(
  from: DateTime(2026, 7),
  to: DateTime(2026, 8, 31),
  currency: 'bam',
  rows: rows ?? <RevenueReportRow>[revenueRow(), revenueRow(month: 8)],
  totals:
      totals ??
      const RevenueReportTotals(
        bookingsCreated: 24,
        bookingsCompleted: 18,
        grossCharged: 9840.50,
        refunded: 420,
        net: 9420.50,
      ),
);

RevenueReportRow revenueRow({
  int year = 2026,
  int month = 7,
  int bookingsCreated = 12,
  int bookingsCompleted = 9,
  double grossCharged = 4920.25,
  double refunded = 210,
  double net = 4710.25,
}) => RevenueReportRow(
  year: year,
  month: month,
  bookingsCreated: bookingsCreated,
  bookingsCompleted: bookingsCompleted,
  grossCharged: grossCharged,
  refunded: refunded,
  net: net,
);

ListingReport listingReport({
  List<ListingReportRow>? rows,
  ListingReportTotals? totals,
}) => ListingReport(
  from: DateTime(2026, 7),
  to: DateTime(2026, 8, 31),
  currency: 'bam',
  rows:
      rows ??
      <ListingReportRow>[
        listingRow(),
        listingRow(
          cityId: 2,
          city: 'Mostar',
          category: 'Apartment',
          averageRating: null,
          reviewCount: 0,
        ),
      ],
  totals:
      totals ??
      const ListingReportTotals(
        listingsPublished: 7,
        bookings: 24,
        unitsSold: 61,
        grossCharged: 9840.50,
        reviewCount: 11,
        averageRating: 4.6,
      ),
);

ListingReportRow listingRow({
  int cityId = 1,
  String city = 'Sarajevo',
  int categoryId = 3,
  String category = 'Villa',
  int listingsPublished = 4,
  int bookings = 14,
  int unitsSold = 38,
  double grossCharged = 6210.75,
  int reviewCount = 11,
  double? averageRating = 4.6,
}) => ListingReportRow(
  cityId: cityId,
  city: city,
  categoryId: categoryId,
  category: category,
  listingsPublished: listingsPublished,
  bookings: bookings,
  unitsSold: unitsSold,
  grossCharged: grossCharged,
  reviewCount: reviewCount,
  averageRating: averageRating,
);
