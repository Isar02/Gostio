import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import 'destination_share.dart';

// What the administrator panel opens with: four figures, the year behind them,
// and the three short lists that say what needs looking at. Money is the
// month's net, for the reason the host's is.
@immutable
class PlatformOverview {
  const PlatformOverview({
    required this.users,
    required this.listings,
    required this.bookingsThisMonth,
    required this.netThisMonth,
    required this.trade,
    required this.destinations,
    required this.latestBookings,
    required this.waiting,
    required this.waitingCount,
  });

  final int users;
  final int listings;
  final int bookingsThisMonth;
  final double netThisMonth;

  // The rolling year, month by month, which is what the trend is drawn from.
  final List<RevenueReportRow> trade;

  final List<DestinationShare> destinations;
  final List<Reservation> latestBookings;

  // The few requests shown, against how many are actually waiting.
  final List<HostApplication> waiting;
  final int waitingCount;
}
