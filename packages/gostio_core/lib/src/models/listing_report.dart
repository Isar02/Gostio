import 'package:json_annotation/json_annotation.dart';

import 'report_document.dart';

part 'listing_report.g.dart';

typedef ListingReport = ReportDocument<ListingReportRow, ListingReportTotals>;

@JsonSerializable(createToJson: false)
class ListingReportRow {
  const ListingReportRow({
    required this.cityId,
    required this.city,
    required this.categoryId,
    required this.category,
    required this.listingsPublished,
    required this.bookings,
    required this.unitsSold,
    required this.grossCharged,
    required this.reviewCount,
    this.averageRating,
  });

  factory ListingReportRow.fromJson(Map<String, dynamic> json) =>
      _$ListingReportRowFromJson(json);

  final int cityId;
  final String city;
  final int categoryId;
  final String category;
  final int listingsPublished;
  final int bookings;

  // Nights for a stay, seats for a term.
  final int unitsSold;

  final double grossCharged;
  final int reviewCount;

  // Absent where nothing in the row has been reviewed.
  final double? averageRating;
}

@JsonSerializable(createToJson: false)
class ListingReportTotals {
  const ListingReportTotals({
    required this.listingsPublished,
    required this.bookings,
    required this.unitsSold,
    required this.grossCharged,
    required this.reviewCount,
    this.averageRating,
  });

  factory ListingReportTotals.fromJson(Map<String, dynamic> json) =>
      _$ListingReportTotalsFromJson(json);

  final int listingsPublished;
  final int bookings;
  final int unitsSold;
  final double grossCharged;
  final int reviewCount;
  final double? averageRating;
}
