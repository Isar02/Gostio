import 'package:flutter/foundation.dart';

// The figures the host panel opens with. Money is the month's net rather than
// what was charged over it: a refund that went back was never earned, and the
// reservation list carries no refund to subtract, which is why this is read
// from the report and not counted here.
@immutable
class HostOverview {
  const HostOverview({
    required this.accommodations,
    required this.experiences,
    required this.bookingsThisMonth,
    required this.netThisMonth,
  });

  final int accommodations;
  final int experiences;
  final int bookingsThisMonth;
  final double netThisMonth;
}
