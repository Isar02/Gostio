import '../../../core/models/paged_result.dart';
import '../../../core/time/calendar_days.dart';
import '../../accommodations/data/accommodation_query.dart';
import '../../accommodations/data/accommodations_repository.dart';
import '../../experiences/data/experience_query.dart';
import '../../experiences/data/experiences_repository.dart';
import '../../host_applications/data/host_application.dart';
import '../../host_applications/data/host_application_query.dart';
import '../../host_applications/data/host_application_status.dart';
import '../../host_applications/data/host_applications_repository.dart';
import '../../listings/data/listing_address.dart';
import '../../reference/data/lookup_item.dart';
import '../../reports/data/listing_report.dart';
import '../../reports/data/report_range.dart';
import '../../reports/data/report_scope.dart';
import '../../reports/data/reports_repository.dart';
import '../../reports/data/revenue_report.dart';
import '../../reservations/data/reservation.dart';
import '../../reservations/data/reservation_query.dart';
import '../../reservations/data/reservations_repository.dart';
import '../../users/data/user_query.dart';
import '../../users/data/users_repository.dart';
import 'destination_share.dart';
import 'host_overview.dart';
import 'overview_month.dart';
import 'platform_overview.dart';

// The overview has no table of its own: it is what the other tables already
// answer, read together. Composing them here rather than in a notifier leaves
// each panel one dependency wide and gives the screens one seam to stand a
// double in.
class OverviewRepository {
  const OverviewRepository({
    required AccommodationsRepository accommodations,
    required ExperiencesRepository experiences,
    required ReservationsRepository reservations,
    required ReportsRepository reports,
    required UsersRepository users,
    required HostApplicationsRepository applications,
  }) : _stays = accommodations,
       _terms = experiences,
       _bookings = reservations,
       _documents = reports,
       _accounts = users,
       _requests = applications;

  // How many rows a panel of the overview shows before it says how many more
  // there are.
  static const int shownRows = 5;

  final AccommodationsRepository _stays;
  final ExperiencesRepository _terms;
  final ReservationsRepository _bookings;
  final ReportsRepository _documents;
  final UsersRepository _accounts;
  final HostApplicationsRepository _requests;

  Future<HostOverview> host(int hostId) async {
    final DateTime today = CalendarDays.today();
    final Future<int> stays = _publishedStays(hostId: hostId);
    final Future<int> terms = _publishedTerms(hostId: hostId);

    // Whose figures these are is the route rather than an id the request
    // carries: the host scope is built on the server from the token.
    final Future<RevenueReport> revenue = _documents.revenue(
      scope: ReportScope.mine,
      range: _monthOf(today),
    );

    await _settled(<Future<Object?>>[stays, terms, revenue]);

    final RevenueReportTotals month = (await revenue).totals;

    return HostOverview(
      accommodations: await stays,
      experiences: await terms,
      bookingsThisMonth: month.bookingsCreated,
      netThisMonth: month.net,
    );
  }

  // Every listing the host owns is a row, a withdrawn one included: taking a
  // listing off the catalogue does not call off the bookings made while it
  // stood, and a month drawn without them would read as an empty one.
  Future<OverviewMonth> month(DateTime month, {required int hostId}) async {
    final DateTime first = CalendarDays.firstOfMonth(month);
    final DateTime last = CalendarDays.addDays(
      CalendarDays.addMonths(first, 1),
      -1,
    );

    final Future<List<LookupItem>> listings = _stays.titles(hostId: hostId);
    final Future<List<Reservation>> bookings = _bookings.forHostWindow(
      hostId,
      from: first,
      to: last,
    );

    await _settled(<Future<Object?>>[listings, bookings]);

    return OverviewMonth.of(
      month: first,
      listings: await listings,
      bookings: await bookings,
      today: CalendarDays.today(),
    );
  }

  Future<PlatformOverview> platform() async {
    final DateTime today = CalendarDays.today();
    final ReportRange year = ReportRange.rollingYearToToday();

    final Future<int> people = _count(
      _accounts.search(query: const UserQuery(), pageSize: 1),
    );
    final Future<int> stays = _publishedStays();
    final Future<int> terms = _publishedTerms();
    final Future<RevenueReport> revenue = _documents.revenue(
      scope: ReportScope.platform,
      range: year,
    );
    final Future<ListingReport> stayCities = _cities(
      year,
      ListingKind.accommodation,
    );
    final Future<ListingReport> termCities = _cities(
      year,
      ListingKind.experience,
    );
    final Future<PagedResult<Reservation>> bookings = _bookings.search(
      query: const ReservationQuery(),
      pageSize: shownRows,
    );
    final Future<PagedResult<HostApplication>> applications = _requests.search(
      query: const HostApplicationQuery(status: HostApplicationStatus.pending),
      pageSize: shownRows,
    );

    await _settled(<Future<Object?>>[
      people,
      stays,
      terms,
      revenue,
      stayCities,
      termCities,
      bookings,
      applications,
    ]);

    final RevenueReport trade = await revenue;
    final RevenueReportRow? month = _monthIn(trade, today);
    final PagedResult<HostApplication> waiting = await applications;

    return PlatformOverview(
      users: await people,
      listings: await stays + await terms,
      bookingsThisMonth: month?.bookingsCreated ?? 0,
      netThisMonth: month?.net ?? 0,
      trade: trade.rows,
      destinations: DestinationShare.ranked(<ListingReportRow>[
        ...(await stayCities).rows,
        ...(await termCities).rows,
      ]),
      latestBookings: (await bookings).items,
      waiting: waiting.items,
      waitingCount: waiting.totalCount,
    );
  }

  Future<ListingReport> _cities(ReportRange range, ListingKind target) =>
      _documents.listings(
        scope: ReportScope.platform,
        range: range,
        target: target,
      );

  Future<int> _publishedStays({int? hostId}) => _count(
    _stays.search(
      query: const AccommodationQuery(isActive: true),
      pageSize: 1,
      hostId: hostId,
    ),
  );

  Future<int> _publishedTerms({int? hostId}) => _count(
    _terms.search(
      query: const ExperienceQuery(isActive: true),
      pageSize: 1,
      hostId: hostId,
    ),
  );

  // Only the count is wanted, so the smallest page the API allows is asked for
  // and the row it answers with is thrown away.
  static Future<int> _count(Future<PagedResult<Object?>> page) async =>
      (await page).totalCount;

  // Every read is started before any of them is waited on, so a panel costs
  // one round trip rather than eight. The wait holds all of them, which keeps
  // a refusal from landing as an error nobody listens for, and it throws the
  // first one the API sent rather than a bundle of every one.
  static Future<void> _settled(List<Future<Object?>> reads) =>
      Future.wait<Object?>(reads);

  static ReportRange _monthOf(DateTime day) =>
      ReportRange(from: CalendarDays.firstOfMonth(day), to: day);

  static RevenueReportRow? _monthIn(RevenueReport trade, DateTime day) {
    for (final RevenueReportRow row in trade.rows) {
      if (row.year == day.year && row.month == day.month) {
        return row;
      }
    }

    return null;
  }
}
