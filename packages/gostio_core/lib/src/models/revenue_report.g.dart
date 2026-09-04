// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'revenue_report.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RevenueReportRow _$RevenueReportRowFromJson(Map<String, dynamic> json) =>
    RevenueReportRow(
      year: (json['year'] as num).toInt(),
      month: (json['month'] as num).toInt(),
      bookingsCreated: (json['bookingsCreated'] as num).toInt(),
      bookingsCompleted: (json['bookingsCompleted'] as num).toInt(),
      grossCharged: (json['grossCharged'] as num).toDouble(),
      refunded: (json['refunded'] as num).toDouble(),
      net: (json['net'] as num).toDouble(),
    );

RevenueReportTotals _$RevenueReportTotalsFromJson(Map<String, dynamic> json) =>
    RevenueReportTotals(
      bookingsCreated: (json['bookingsCreated'] as num).toInt(),
      bookingsCompleted: (json['bookingsCompleted'] as num).toInt(),
      grossCharged: (json['grossCharged'] as num).toDouble(),
      refunded: (json['refunded'] as num).toDouble(),
      net: (json['net'] as num).toDouble(),
    );
