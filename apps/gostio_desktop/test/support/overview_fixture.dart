import 'package:gostio_desktop/features/overview/data/host_overview.dart';

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
