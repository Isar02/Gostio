import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/core/time/calendar_days.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_query.dart';
import 'package:gostio_desktop/features/host_applications/data/host_application_status.dart';
import 'package:gostio_desktop/features/listings/data/listing_address.dart';
import 'package:gostio_desktop/features/overview/data/host_overview.dart';
import 'package:gostio_desktop/features/overview/data/overview_month.dart';
import 'package:gostio_desktop/features/overview/data/overview_repository.dart';
import 'package:gostio_desktop/features/overview/data/platform_overview.dart';
import 'package:gostio_desktop/features/reports/data/listing_report.dart';
import 'package:gostio_desktop/features/reports/data/report_range.dart';
import 'package:gostio_desktop/features/reports/data/report_scope.dart';
import 'package:gostio_desktop/features/reports/data/revenue_report.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';

import '../../../support/booking_fixture.dart';
import '../../../support/overview_doubles.dart';
import '../../../support/report_fixture.dart';

void main() {
  group('the host panel', () {
    test('counts only what stands in the catalogue', () async {
      final OverviewStaysDouble stays = OverviewStaysDouble(published: 3);
      final OverviewTermsDouble terms = OverviewTermsDouble(published: 2);
      final HostOverview overview = await _repository(
        stays: stays,
        terms: terms,
      ).host(7);

      expect(overview.accommodations, 3);
      expect(overview.experiences, 2);
      expect(stays.queries.single.toParameters(), <String, dynamic>{
        'isActive': true,
      });
      expect(stays.searchedHosts, <int?>[7]);
      expect(terms.searchedHosts, <int?>[7]);
    });

    // Whose figures these are is the route rather than an id the request
    // carries, and the month is this one alone.
    test('reads the report family the panel is in, over this month', () async {
      final OverviewReportsDouble reports = OverviewReportsDouble();
      final DateTime today = CalendarDays.today();

      await _repository(reports: reports).host(7);

      expect(reports.scopes.single, ReportScope.mine);
      expect(reports.ranges.single.from, CalendarDays.firstOfMonth(today));
      expect(reports.ranges.single.to, today);
      expect(reports.targets, isEmpty);
    });

    // A refund that went back was never earned, so the figure is the net the
    // report answers rather than what was charged.
    test('the money is the net of the month', () async {
      final HostOverview overview = await _repository(
        reports: OverviewReportsDouble(
          revenue: revenueReport(
            totals: const RevenueReportTotals(
              bookingsCreated: 9,
              bookingsCompleted: 6,
              grossCharged: 4200,
              refunded: 300,
              net: 3900,
            ),
          ),
        ),
      ).host(7);

      expect(overview.bookingsThisMonth, 9);
      expect(overview.netThisMonth, 3900);
    });

    // A refusal is the sentence the API sent rather than a bundle of every
    // read that was in flight beside it.
    test('a read that is refused is refused as it stands', () async {
      expect(
        () => _repository(stays: _RefusingStays()).host(7),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('the month', () {
    test('is asked for over the days the month actually has', () async {
      final OverviewBookingsDouble bookings = OverviewBookingsDouble();

      await _repository(bookings: bookings)
          .month(DateTime(2026, 2, 17), hostId: 7);

      expect(bookings.windowedHosts, <int>[7]);
      expect(bookings.windows.single, (
        DateTime(2026, 2),
        DateTime(2026, 2, 28),
      ));
    });

    // Taking a listing off the catalogue does not call off the bookings made
    // while it stood, so every listing the host owns is a row.
    test('lays the bookings over every listing the host owns', () async {
      final OverviewMonth month = await _repository(
        bookings: OverviewBookingsDouble(
          window: <Reservation>[
            booking(
              accommodationId: 4,
              checkInDate: DateTime(2026, 9, 8),
              checkOutDate: DateTime(2026, 9, 11),
            ),
          ],
        ),
      ).month(DateTime(2026, 9), hostId: 7);

      expect(month.rows.single.listing.id, 4);
      expect(month.rows.single.spans.single.span, 3);
    });
  });

  group('the administrator panel', () {
    test('reads the platform rather than the caller', () async {
      final OverviewReportsDouble reports = OverviewReportsDouble();
      final OverviewStaysDouble stays = OverviewStaysDouble();

      await _repository(reports: reports, stays: stays).platform();

      expect(reports.scopes, everyElement(ReportScope.platform));
      expect(reports.ranges.first, ReportRange.rollingYearToToday());
      expect(stays.searchedHosts, <int?>[null]);
    });

    test('the figures are the row for the month the clock is in', () async {
      final DateTime today = CalendarDays.today();
      final PlatformOverview overview = await _repository(
        reports: OverviewReportsDouble(
          revenue: revenueReport(
            rows: <RevenueReportRow>[
              revenueRow(
                year: today.year,
                month: today.month,
                bookingsCreated: 31,
                net: 8400,
              ),
              revenueRow(
                year: today.year - 1,
                month: today.month,
                bookingsCreated: 12,
                net: 900,
              ),
            ],
          ),
        ),
        users: OverviewUsersDouble(registered: 41),
        stays: OverviewStaysDouble(published: 12),
        terms: OverviewTermsDouble(published: 5),
      ).platform();

      expect(overview.users, 41);
      expect(overview.listings, 17);
      expect(overview.bookingsThisMonth, 31);
      expect(overview.netThisMonth, 8400);
      expect(overview.trade, hasLength(2));
    });

    // A month the document has no row for is a month with nothing in it, not
    // a screen with nothing on it.
    test('a month the report never answered reads as nothing', () async {
      final PlatformOverview overview = await _repository(
        reports: OverviewReportsDouble(
          revenue: revenueReport(rows: const <RevenueReportRow>[]),
        ),
      ).platform();

      expect(overview.bookingsThisMonth, 0);
      expect(overview.netThisMonth, 0);
    });

    test('both catalogues are ranked into the same destinations', () async {
      final PlatformOverview overview = await _repository(
        reports: OverviewReportsDouble(
          cities: <ListingKind, ListingReport>{
            ListingKind.accommodation: listingReport(
              rows: <ListingReportRow>[
                listingRow(
                  cityId: 1,
                  city: 'Sarajevo',
                  bookings: 4,
                  grossCharged: 1000,
                ),
              ],
            ),
            ListingKind.experience: listingReport(
              rows: <ListingReportRow>[
                listingRow(
                  cityId: 1,
                  city: 'Sarajevo',
                  bookings: 2,
                  grossCharged: 400,
                ),
                listingRow(
                  cityId: 2,
                  city: 'Mostar',
                  bookings: 9,
                  grossCharged: 2100,
                ),
              ],
            ),
          },
        ),
      ).platform();

      expect(overview.destinations.first.city, 'Mostar');
      expect(overview.destinations.last.city, 'Sarajevo');
      expect(overview.destinations.last.bookings, 6);
      expect(overview.destinations.last.grossCharged, 1400);
    });

    test('the two lists are the few rows a panel shows', () async {
      final OverviewBookingsDouble bookings = OverviewBookingsDouble(
        latest: <Reservation>[booking(), booking(id: 2)],
      );
      final OverviewApplicationsDouble applications =
          OverviewApplicationsDouble(waiting: 14);
      final PlatformOverview overview = await _repository(
        bookings: bookings,
        applications: applications,
      ).platform();

      expect(bookings.pageSizes.single, OverviewRepository.shownRows);
      expect(overview.latestBookings, hasLength(2));
      expect(applications.queries.single.status, HostApplicationStatus.pending);
      expect(overview.waiting, hasLength(1));
      expect(overview.waitingCount, 14);
    });
  });
}

OverviewRepository _repository({
  OverviewStaysDouble? stays,
  OverviewTermsDouble? terms,
  OverviewBookingsDouble? bookings,
  OverviewReportsDouble? reports,
  OverviewUsersDouble? users,
  OverviewApplicationsDouble? applications,
}) => OverviewRepository(
  accommodations: stays ?? OverviewStaysDouble(),
  experiences: terms ?? OverviewTermsDouble(),
  reservations: bookings ?? OverviewBookingsDouble(),
  reports: reports ?? OverviewReportsDouble(),
  users: users ?? OverviewUsersDouble(),
  applications: applications ?? OverviewApplicationsDouble(),
);

class _RefusingStays extends OverviewStaysDouble {
  @override
  Future<PagedResult<Accommodation>> search({
    required AccommodationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) => throw const ApiException(
    message: 'The catalogue could not be read.',
    traceId: 'c71f04',
  );
}
