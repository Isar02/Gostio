import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/overview/data/destination_share.dart';
import 'package:gostio_desktop/features/reports/data/listing_report.dart';

import '../../../support/report_fixture.dart';

void main() {
  // The report answers a row to a city and a category together, and both
  // catalogues answer a document of their own.
  test('the categories under one city are summed back into it', () {
    final List<DestinationShare> ranked = DestinationShare.ranked(
      <ListingReportRow>[
        listingRow(bookings: 4, grossCharged: 1200),
        listingRow(
          categoryId: 8,
          category: 'Apartment',
          bookings: 3,
          grossCharged: 800,
        ),
      ],
    );

    expect(ranked.single.city, 'Sarajevo');
    expect(ranked.single.bookings, 7);
    expect(ranked.single.grossCharged, 2000);
  });

  test('the cities are ordered by what they took', () {
    final List<DestinationShare> ranked = DestinationShare.ranked(
      <ListingReportRow>[
        listingRow(cityId: 1, city: 'Sarajevo', bookings: 2, grossCharged: 900),
        listingRow(cityId: 2, city: 'Mostar', bookings: 5, grossCharged: 2400),
        listingRow(cityId: 3, city: 'Tuzla', bookings: 3, grossCharged: 1500),
      ],
    );

    expect(ranked.map((DestinationShare share) => share.city), <String>[
      'Mostar',
      'Tuzla',
      'Sarajevo',
    ]);
  });

  // A city nobody booked is not a destination, so it is left out rather than
  // ranked last.
  test('a city nobody booked is not ranked', () {
    final List<DestinationShare> ranked = DestinationShare.ranked(
      <ListingReportRow>[
        listingRow(cityId: 1, city: 'Sarajevo', bookings: 2, grossCharged: 900),
        listingRow(cityId: 7, city: 'Trebinje', bookings: 0, grossCharged: 0),
      ],
    );

    expect(ranked.map((DestinationShare share) => share.city), <String>[
      'Sarajevo',
    ]);
  });

  test('only as many as the panel shows come back', () {
    final List<DestinationShare> ranked = DestinationShare.ranked(
      <ListingReportRow>[
        for (int city = 1; city <= 8; city++)
          listingRow(
            cityId: city,
            city: 'City $city',
            grossCharged: city * 100,
          ),
      ],
      take: 3,
    );

    expect(ranked, hasLength(3));
    expect(ranked.first.city, 'City 8');
  });

  test('nothing traded ranks nothing', () {
    expect(DestinationShare.ranked(const <ListingReportRow>[]), isEmpty);
  });
}
