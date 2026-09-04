import 'package:json_annotation/json_annotation.dart';

part 'report_document.g.dart';

@JsonSerializable(createToJson: false, genericArgumentFactories: true)
class ReportDocument<TRow, TTotals> {
  const ReportDocument({
    required this.from,
    required this.to,
    required this.currency,
    required this.rows,
    required this.totals,
  });

  factory ReportDocument.fromJson(
    Map<String, dynamic> json,
    TRow Function(Object? json) fromJsonRow,
    TTotals Function(Object? json) fromJsonTotals,
  ) => _$ReportDocumentFromJson<TRow, TTotals>(
    json,
    fromJsonRow,
    fromJsonTotals,
  );

  // Calendar days rather than moments: the API answers them as yyyy-MM-dd.
  final DateTime from;
  final DateTime to;

  final String currency;
  final List<TRow> rows;
  final TTotals totals;

  bool get isEmpty => rows.isEmpty;
}
