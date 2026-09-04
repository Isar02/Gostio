import 'package:gostio_desktop/features/host_applications/data/host_application.dart';
import 'package:gostio_desktop/features/overview/data/destination_share.dart';
import 'package:gostio_desktop/features/overview/data/host_overview.dart';
import 'package:gostio_desktop/features/overview/data/platform_overview.dart';
import 'package:gostio_desktop/features/reports/data/revenue_report.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';

import 'application_fixture.dart';
import 'booking_fixture.dart';
import 'report_fixture.dart';

// The figures a host panel opens with. What a test is about it names itself.
HostOverview hostOverview({
  int accommodations = 3,
  int experiences = 2,
  int bookingsThisMonth = 18,
  double netThisMonth = 3240,
}) => HostOverview(
  accommodations: accommodations,
  experiences: experiences,
  bookingsThisMonth: bookingsThisMonth,
  netThisMonth: netThisMonth,
);

// The administrator's whole panel, in the shape the repository assembles it.
PlatformOverview platformOverview({
  int users = 1247,
  int listings = 312,
  int bookingsThisMonth = 489,
  double netThisMonth = 24580,
  List<RevenueReportRow>? trade,
  List<DestinationShare>? destinations,
  List<Reservation>? latestBookings,
  List<HostApplication>? waiting,
  int waitingCount = 3,
}) => PlatformOverview(
  users: users,
  listings: listings,
  bookingsThisMonth: bookingsThisMonth,
  netThisMonth: netThisMonth,
  trade: trade ?? <RevenueReportRow>[revenueRow(), revenueRow(month: 8)],
  destinations:
      destinations ??
      const <DestinationShare>[
        DestinationShare(city: 'Sarajevo', bookings: 14, grossCharged: 6210.75),
        DestinationShare(city: 'Mostar', bookings: 9, grossCharged: 3120.50),
      ],
  latestBookings: latestBookings ?? <Reservation>[booking()],
  waiting: waiting ?? <HostApplication>[application()],
  waitingCount: waitingCount,
);
