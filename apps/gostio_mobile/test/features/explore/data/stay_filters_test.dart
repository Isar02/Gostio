import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/calendar/date_range.dart';
import 'package:gostio_mobile/features/explore/data/listing_filters.dart';
import 'package:gostio_mobile/features/explore/data/stay_filters.dart';

void main() {
  const LookupItem mostar = LookupItem(id: 3, name: 'Mostar');
  const LookupItem wifi = LookupItem(id: 1, name: 'Wi-Fi');
  const LookupItem parking = LookupItem(id: 2, name: 'Parking');

  test('a search nobody has narrowed still asks only for what is on offer', () {
    expect(const StayFilters().toParameters(), <String, dynamic>{
      'isActive': true,
    });
  });

  test('a filter nobody set is left out rather than sent empty', () {
    final JsonMap sent = const StayFilters(city: mostar).toParameters();

    expect(sent['cityId'], 3);
    expect(sent.containsKey('minPrice'), isFalse);
    expect(sent.containsKey('amenityIds'), isFalse);
  });

  test('words with nothing in them are not a search for a title', () {
    expect(
      const StayFilters()
          .searchingFor('   ')
          .toParameters()
          .containsKey('title'),
      isFalse,
    );
  });

  test('the words a reader typed are trimmed before they are sent', () {
    expect(
      const StayFilters().searchingFor('  loft ').toParameters()['title'],
      'loft',
    );
  });

  test('amenities are sent as the ids of every one asked for', () {
    final JsonMap sent = const StayFilters(
      amenities: <LookupItem>[wifi, parking],
    ).toParameters();

    expect(sent['amenityIds'], <int>[1, 2]);
  });

  // The API refuses a half-written stay, and a range is the only way this
  // holds one, so the two dates can only ever be sent together.
  test('the nights asked for are sent as both of their ends', () {
    final JsonMap sent = StayFilters(
      nights: DateRange(from: DateTime(2026, 6, 12), to: DateTime(2026, 6, 15)),
    ).toParameters();

    expect(sent['availableFrom'], '2026-06-12');
    expect(sent['availableTo'], '2026-06-15');
  });

  test('a chip names the nights rather than the dates behind them', () {
    final StayFilters filters = StayFilters(
      nights: DateRange(from: DateTime(2026, 6, 12), to: DateTime(2026, 6, 15)),
    );

    expect(filters.applied.single.label, '3 nights from 12 Jun 2026');
  });

  test('a price band is one chip whichever of its ends were given', () {
    expect(
      const StayFilters(minPrice: 40).applied.single.label,
      'From ${AppNumbers.money(40)}',
    );
    expect(
      const StayFilters(maxPrice: 90).applied.single.label,
      'Up to ${AppNumbers.money(90)}',
    );
    expect(
      const StayFilters(minPrice: 40, maxPrice: 90).applied.single.label,
      '${AppNumbers.money(40)} to ${AppNumbers.money(90)}',
    );
  });

  // One chip is one gesture, and taking off a band is taking off both of its
  // ends: a band with one end left is a filter nobody asked for.
  test('taking off a price band takes off both of its ends', () {
    const StayFilters filters = StayFilters(minPrice: 40, maxPrice: 90);

    expect(filters.applied.single.without, const StayFilters());
  });

  test('one amenity is taken off without disturbing the others', () {
    const StayFilters filters = StayFilters(
      amenities: <LookupItem>[wifi, parking],
    );
    final AppliedFilter<StayFilters> chip = filters.applied.firstWhere(
      (AppliedFilter<StayFilters> filter) => filter.label == 'Wi-Fi',
    );

    expect(chip.without, const StayFilters(amenities: <LookupItem>[parking]));
  });

  test('every filter in force is one chip', () {
    final StayFilters filters = StayFilters(
      title: 'loft',
      city: mostar,
      guests: 2,
      minPrice: 40,
      amenities: const <LookupItem>[wifi, parking],
      nights: DateRange(from: DateTime(2026, 6, 12), to: DateTime(2026, 6, 15)),
    );

    // The words typed are not a chip: they are still in the field above them.
    expect(
      filters.applied.map((AppliedFilter<StayFilters> chip) => chip.label),
      <String>[
        '3 nights from 12 Jun 2026',
        'Mostar',
        '2 guests',
        'From ${AppNumbers.money(40)}',
        'Wi-Fi',
        'Parking',
      ],
    );
  });

  test('clearing the filters keeps the words the reader typed', () {
    const StayFilters filters = StayFilters(
      title: 'loft',
      city: mostar,
      guests: 2,
    );

    expect(filters.cleared, const StayFilters(title: 'loft'));
    expect(filters.cleared.isFiltered, isFalse);
  });

  test('two searches for the same thing are the same search', () {
    expect(
      const StayFilters(city: mostar, amenities: <LookupItem>[wifi]),
      const StayFilters(city: mostar, amenities: <LookupItem>[wifi]),
    );
  });
}
