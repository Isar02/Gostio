import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/report_range.dart';
import '../data/report_scope.dart';
import '../data/reports_repository.dart';

enum ReportKind {
  revenue('Revenue', 'revenue'),
  listings('Listing performance', 'listings');

  const ReportKind(this.title, this.slug);

  final String title;

  // What a saved file is named after.
  final String slug;
}

class ReportsNotifier extends ScreenNotifier {
  ReportsNotifier(this._reports, {required this.scope})
    : _range = ReportRange.rollingYearToToday();

  final ReportsRepository _reports;
  final ReportScope scope;

  int _request = 0;
  bool _isLoading = false;
  ReportKind _kind = ReportKind.revenue;
  ReportRange _range;
  ListingKind _catalogue = ListingKind.accommodation;
  ApiException? _failure;
  RevenueReport? _revenue;
  ListingReport? _listings;

  ReportKind get kind => _kind;

  ReportRange get range => _range;

  ListingKind get catalogue => _catalogue;

  bool get isLoading => _isLoading;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  RevenueReport? get revenue => _revenue;

  ListingReport? get listings => _listings;

  Future<void> showReport(ReportKind kind) {
    if (kind == _kind) {
      return _settled();
    }

    _kind = kind;

    if (_isHeld) {
      ++_request;

      return _settled(announcing: true);
    }

    return _load();
  }

  // A document read over dates that have moved is not the one on the filters.
  Future<void> applyRange(ReportRange range) {
    if (range == _range) {
      return _settled();
    }

    _range = range;
    _revenue = null;
    _listings = null;

    return _load();
  }

  Future<void> applyCatalogue(ListingKind catalogue) {
    if (catalogue == _catalogue) {
      return _settled();
    }

    _catalogue = catalogue;
    _listings = null;

    return _kind == ReportKind.listings ? _load() : _settled(announcing: true);
  }

  Future<void> reload() => _load();

  bool get _isHeld => switch (_kind) {
    ReportKind.revenue => _revenue != null,
    ReportKind.listings => _listings != null,
  };

  Future<void> _settled({bool announcing = false}) {
    if (announcing) {
      publish();
    }

    return Future<void>.value();
  }

  Future<void> _load() async {
    // Taken before the range is judged, or an answer to a request made under
    // dates since made unaskable would still land.
    final int request = ++_request;

    if (!_range.isAskable) {
      _failure = null;
      _isLoading = false;
      publish();

      return;
    }

    final ReportKind asked = _kind;

    _isLoading = true;
    _failure = null;
    publish();

    RevenueReport? revenue;
    ListingReport? listings;
    ApiException? failure;

    try {
      switch (asked) {
        case ReportKind.revenue:
          revenue = await _reports.revenue(scope: scope, range: _range);
        case ReportKind.listings:
          listings = await _reports.listings(
            scope: scope,
            range: _range,
            target: _catalogue,
          );
      }
    } on ApiException catch (thrown) {
      failure = thrown;
    }

    if (request != _request) {
      return;
    }

    switch (asked) {
      case ReportKind.revenue:
        _revenue = revenue;
      case ReportKind.listings:
        _listings = listings;
    }

    _failure = failure;
    _isLoading = false;
    publish();
  }
}
