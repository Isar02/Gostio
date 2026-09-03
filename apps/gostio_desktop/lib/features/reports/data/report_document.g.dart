// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_document.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReportDocument<TRow, TTotals> _$ReportDocumentFromJson<TRow, TTotals>(
  Map<String, dynamic> json,
  TRow Function(Object? json) fromJsonTRow,
  TTotals Function(Object? json) fromJsonTTotals,
) => ReportDocument<TRow, TTotals>(
  from: DateTime.parse(json['from'] as String),
  to: DateTime.parse(json['to'] as String),
  currency: json['currency'] as String,
  rows: (json['rows'] as List<dynamic>).map(fromJsonTRow).toList(),
  totals: fromJsonTTotals(json['totals']),
);
