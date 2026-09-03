import 'package:flutter/foundation.dart';

import '../../reports/data/listing_report.dart';

// Where the platform's trade actually happened. The listing report answers a
// row to a city and a category together, and each catalogue answers a document
// of its own, so the rows are summed back into the city they name.
@immutable
class DestinationShare {
  const DestinationShare({
    required this.city,
    required this.bookings,
    required this.grossCharged,
  });

  // A city nobody booked is not a destination, so it is left out rather than
  // ranked last: the list is meant to be read as the places guests went to.
  static List<DestinationShare> ranked(
    List<ListingReportRow> rows, {
    int take = 5,
  }) {
    final Map<int, DestinationShare> byCity = <int, DestinationShare>{};

    for (final ListingReportRow row in rows) {
      final DestinationShare? held = byCity[row.cityId];

      byCity[row.cityId] = DestinationShare(
        city: row.city,
        bookings: (held?.bookings ?? 0) + row.bookings,
        grossCharged: (held?.grossCharged ?? 0) + row.grossCharged,
      );
    }

    final List<DestinationShare> ranked =
        byCity.values
            .where((DestinationShare share) => share.bookings > 0)
            .toList()
          ..sort(
            (DestinationShare a, DestinationShare b) =>
                b.grossCharged.compareTo(a.grossCharged),
          );

    return ranked.take(take).toList(growable: false);
  }

  final String city;
  final int bookings;
  final double grossCharged;
}
