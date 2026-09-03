import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/models/user.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_query.dart';
import 'package:gostio_desktop/features/experiences/data/experience.dart';
import 'package:gostio_desktop/features/experiences/data/experience_query.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application_query.dart';
import 'package:gostio_desktop/features/host_applications/data/host_applications_repository.dart';
import 'package:gostio_desktop/features/listings/data/listing_address.dart';
import 'package:gostio_desktop/features/reports/data/listing_report.dart';
import 'package:gostio_desktop/features/reports/data/report_range.dart';
import 'package:gostio_desktop/features/reports/data/report_scope.dart';
import 'package:gostio_desktop/features/reports/data/reports_repository.dart';
import 'package:gostio_desktop/features/reports/data/revenue_report.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';
import 'package:gostio_desktop/features/reservations/data/reservation_query.dart';
import 'package:gostio_desktop/features/users/data/user_query.dart';

import 'account_fixture.dart';
import 'application_fixture.dart';
import 'bookings_double.dart';
import 'catalogue_doubles.dart';
import 'report_fixture.dart';
import 'users_double.dart';

// The overview reads six repositories at once, which is more of each of them
// than any other screen touches. Each of these answers only the calls it makes
// and records what it was asked, over the double that already refuses the rest.

class OverviewStaysDouble extends StaysDouble {
  OverviewStaysDouble({this.published = 3, super.titleRows});

  final int published;
  final List<AccommodationQuery> queries = <AccommodationQuery>[];
  final List<int?> searchedHosts = <int?>[];

  @override
  Future<PagedResult<Accommodation>> search({
    required AccommodationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) async {
    queries.add(query);
    searchedHosts.add(hostId);

    return PagedResult<Accommodation>(
      items: const <Accommodation>[],
      page: page,
      pageSize: pageSize,
      totalCount: published,
    );
  }
}

class OverviewTermsDouble extends TermsDouble {
  OverviewTermsDouble({this.published = 2});

  final int published;
  final List<ExperienceQuery> queries = <ExperienceQuery>[];
  final List<int?> searchedHosts = <int?>[];

  @override
  Future<PagedResult<Experience>> search({
    required ExperienceQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) async {
    queries.add(query);
    searchedHosts.add(hostId);

    return PagedResult<Experience>(
      items: const <Experience>[],
      page: page,
      pageSize: pageSize,
      totalCount: published,
    );
  }
}

class OverviewBookingsDouble extends BookingsDouble {
  OverviewBookingsDouble({
    this.latest = const <Reservation>[],
    this.window = const <Reservation>[],
  });

  final List<Reservation> latest;
  final List<Reservation> window;
  final List<int> windowedHosts = <int>[];
  final List<(DateTime, DateTime)> windows = <(DateTime, DateTime)>[];
  final List<int> pageSizes = <int>[];

  @override
  Future<PagedResult<Reservation>> search({
    required ReservationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) async {
    pageSizes.add(pageSize);

    return PagedResult<Reservation>(
      items: latest,
      page: page,
      pageSize: pageSize,
      totalCount: latest.length,
    );
  }

  @override
  Future<List<Reservation>> forHostWindow(
    int hostId, {
    required DateTime from,
    required DateTime to,
  }) async {
    windowedHosts.add(hostId);
    windows.add((from, to));

    return window;
  }
}

class OverviewUsersDouble extends UsersDouble {
  OverviewUsersDouble({this.registered = 41});

  final int registered;

  @override
  Future<PagedResult<User>> search({
    required UserQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async => PagedResult<User>(
    items: <User>[account()],
    page: page,
    pageSize: pageSize,
    totalCount: registered,
  );
}

class OverviewApplicationsDouble implements HostApplicationsRepository {
  OverviewApplicationsDouble({this.waiting = 2});

  final int waiting;
  final List<HostApplicationQuery> queries = <HostApplicationQuery>[];

  @override
  Future<PagedResult<HostApplication>> search({
    required HostApplicationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    queries.add(query);

    return PagedResult<HostApplication>(
      items: <HostApplication>[application()],
      page: page,
      pageSize: pageSize,
      totalCount: waiting,
    );
  }

  @override
  Future<HostApplication> get(int id) => throw UnimplementedError();

  @override
  Future<HostApplication> approve(int id, {String? reason}) =>
      throw UnimplementedError();

  @override
  Future<HostApplication> reject(int id, {required String reason}) =>
      throw UnimplementedError();
}

// The two documents, each answerable per catalogue so a test can say what a
// city took on either side of it.
class OverviewReportsDouble implements ReportsRepository {
  OverviewReportsDouble({RevenueReport? revenue, this.cities})
    : revenueDocument = revenue ?? revenueReport();

  final RevenueReport revenueDocument;
  final Map<ListingKind, ListingReport>? cities;

  final List<ReportScope> scopes = <ReportScope>[];
  final List<ReportRange> ranges = <ReportRange>[];
  final List<ListingKind> targets = <ListingKind>[];

  @override
  Future<RevenueReport> revenue({
    required ReportScope scope,
    required ReportRange range,
  }) async {
    scopes.add(scope);
    ranges.add(range);

    return revenueDocument;
  }

  @override
  Future<ListingReport> listings({
    required ReportScope scope,
    required ReportRange range,
    required ListingKind target,
  }) async {
    targets.add(target);

    return cities?[target] ?? listingReport(rows: const <ListingReportRow>[]);
  }
}
