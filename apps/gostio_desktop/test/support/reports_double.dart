import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/reports/data/report_range.dart';
import 'package:gostio_desktop/features/reports/data/report_scope.dart';
import 'package:gostio_desktop/features/reports/data/reports_repository.dart';

import 'report_fixture.dart';

// What the API was asked for and what it answered. Held calls are the way a
// test decides which of two requests lands first.
class ReportsDouble implements ReportsRepository {
  ReportsDouble({this.failing = false, this.holds = false});

  final bool failing;
  final bool holds;

  final List<ReportScope> scopes = <ReportScope>[];
  final List<ReportRange> revenueRanges = <ReportRange>[];
  final List<ReportRange> listingRanges = <ReportRange>[];
  final List<ListingKind> targets = <ListingKind>[];
  final List<Completer<void>> waits = <Completer<void>>[];

  int get asked => revenueRanges.length + listingRanges.length;

  @override
  Future<RevenueReport> revenue({
    required ReportScope scope,
    required ReportRange range,
  }) async {
    scopes.add(scope);
    revenueRanges.add(range);
    await _held();

    return _refuseOr(() => revenueReport());
  }

  @override
  Future<ListingReport> listings({
    required ReportScope scope,
    required ReportRange range,
    required ListingKind target,
  }) async {
    scopes.add(scope);
    listingRanges.add(range);
    targets.add(target);
    await _held();

    return _refuseOr(() => listingReport());
  }

  Future<void> _held() {
    if (!holds) {
      return Future<void>.value();
    }

    final Completer<void> wait = Completer<void>();
    waits.add(wait);

    return wait.future;
  }

  T _refuseOr<T>(T Function() answer) {
    if (failing) {
      throw const ApiException(
        message: 'The report could not be built.',
        traceId: 'b41c09',
      );
    }

    return answer();
  }
}
