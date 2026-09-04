import 'package:gostio_core/gostio_core.dart';

import 'report_range.dart';
import 'report_scope.dart';

// Neither report is paged: a document is read whole or not at all.
class ReportsRepository {
  const ReportsRepository(this._client);

  final ApiClient _client;

  Future<RevenueReport> revenue({
    required ReportScope scope,
    required ReportRange range,
  }) async => RevenueReport.fromJson(
    await _client.get('${scope.root}/revenue', query: range.toParameters()),
    (Object? row) => RevenueReportRow.fromJson(row! as JsonMap),
    (Object? totals) => RevenueReportTotals.fromJson(totals! as JsonMap),
  );

  Future<ListingReport> listings({
    required ReportScope scope,
    required ReportRange range,
    required ListingKind target,
  }) async => ListingReport.fromJson(
    await _client.get(
      '${scope.root}/listings',
      query: <String, dynamic>{
        ...range.toParameters(),
        'target': target.catalogueName,
      },
    ),
    (Object? row) => ListingReportRow.fromJson(row! as JsonMap),
    (Object? totals) => ListingReportTotals.fromJson(totals! as JsonMap),
  );
}
