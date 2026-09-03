import 'package:json_annotation/json_annotation.dart';

import 'report_document.dart';

part 'revenue_report.g.dart';

typedef RevenueReport = ReportDocument<RevenueReportRow, RevenueReportTotals>;

// One month of trade. Every month the range touches gets a row, including the
// ones nothing happened in, so the document has no gap where a month should be.
@JsonSerializable(createToJson: false)
class RevenueReportRow {
  const RevenueReportRow({
    required this.year,
    required this.month,
    required this.bookingsCreated,
    required this.bookingsCompleted,
    required this.grossCharged,
    required this.refunded,
    required this.net,
  });

  factory RevenueReportRow.fromJson(Map<String, dynamic> json) =>
      _$RevenueReportRowFromJson(json);

  final int year;
  final int month;
  final int bookingsCreated;
  final int bookingsCompleted;
  final double grossCharged;
  final double refunded;
  final double net;

  DateTime get monthStart => DateTime(year, month);
}

@JsonSerializable(createToJson: false)
class RevenueReportTotals {
  const RevenueReportTotals({
    required this.bookingsCreated,
    required this.bookingsCompleted,
    required this.grossCharged,
    required this.refunded,
    required this.net,
  });

  factory RevenueReportTotals.fromJson(Map<String, dynamic> json) =>
      _$RevenueReportTotalsFromJson(json);

  final int bookingsCreated;
  final int bookingsCompleted;
  final double grossCharged;
  final double refunded;
  final double net;
}
