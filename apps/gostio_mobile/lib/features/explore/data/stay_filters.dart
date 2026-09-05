import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/calendar/date_range.dart';
import 'listing_filters.dart';

// What a guest is asking the stay catalogue. A named thing is held as the row
// the reader chose rather than as its id alone, because the chip under the
// field has to print what they picked and nothing here should have to look a
// name up a second time to draw it.
@immutable
class StayFilters implements ListingFilters<StayFilters> {
  const StayFilters({
    this.title,
    this.city,
    this.type,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.guests,
    this.amenities = const <LookupItem>[],
    this.nights,
  });

  @override
  final String? title;

  final LookupItem? city;
  final LookupItem? type;
  final LookupItem? category;
  final double? minPrice;
  final double? maxPrice;
  final int? guests;
  final List<LookupItem> amenities;

  // The nights asked for, which the API reads as [from, to): a stay checks out
  // on the day it ends and that day is free for somebody else.
  final DateRange? nights;

  bool get isFiltered => applied.isNotEmpty;

  @override
  StayFilters get cleared => StayFilters(title: title);

  @override
  StayFilters searchingFor(String? title) => replacing(title: written(title));

  @override
  List<AppliedFilter<StayFilters>> get applied => <AppliedFilter<StayFilters>>[
    if (nights case final DateRange nights)
      AppliedFilter<StayFilters>(
        '${nights.nights} ${nights.nights == 1 ? "night" : "nights"} '
        'from ${AppDates.day(nights.from)}',
        replacing(nights: null),
      ),
    if (city case final LookupItem city)
      AppliedFilter<StayFilters>(city.name, replacing(city: null)),
    if (guests case final int guests)
      AppliedFilter<StayFilters>(
        '$guests ${guests == 1 ? "guest" : "guests"}',
        replacing(guests: null),
      ),
    if (priceLabel(minPrice, maxPrice) case final String label)
      AppliedFilter<StayFilters>(
        label,
        replacing(minPrice: null, maxPrice: null),
      ),
    if (type case final LookupItem type)
      AppliedFilter<StayFilters>(type.name, replacing(type: null)),
    if (category case final LookupItem category)
      AppliedFilter<StayFilters>(category.name, replacing(category: null)),
    for (final LookupItem amenity in amenities)
      AppliedFilter<StayFilters>(
        amenity.name,
        replacing(
          amenities: <LookupItem>[
            for (final LookupItem kept in amenities)
              if (kept != amenity) kept,
          ],
        ),
      ),
  ];

  @override
  JsonMap toParameters() => <String, dynamic>{
    // Explore is what a guest can book. A host browsing their own catalogue
    // would otherwise meet the listing they withdrew, which the API is right
    // to show them and this screen is the wrong place to show it.
    'isActive': true,
    'title': ?written(title),
    'cityId': ?city?.id,
    'accommodationTypeId': ?type?.id,
    'accommodationCategoryId': ?category?.id,
    'minPrice': ?minPrice,
    'maxPrice': ?maxPrice,
    'minGuests': ?guests,
    if (amenities.isNotEmpty)
      'amenityIds': <int>[
        for (final LookupItem amenity in amenities) amenity.id,
      ],
    // Both dates or neither: one bound names no nights, and the API refuses a
    // half-written stay rather than guessing at the other end.
    if (nights case final DateRange nights) ...<String, dynamic>{
      'availableFrom': CalendarDays.write(nights.from),
      'availableTo': CalendarDays.write(nights.to),
    },
  };

  StayFilters replacing({
    Object? title = unchanged,
    Object? city = unchanged,
    Object? type = unchanged,
    Object? category = unchanged,
    Object? minPrice = unchanged,
    Object? maxPrice = unchanged,
    Object? guests = unchanged,
    Object? nights = unchanged,
    List<LookupItem>? amenities,
  }) => StayFilters(
    title: carried(title, this.title),
    city: carried(city, this.city),
    type: carried(type, this.type),
    category: carried(category, this.category),
    minPrice: carried(minPrice, this.minPrice),
    maxPrice: carried(maxPrice, this.maxPrice),
    guests: carried(guests, this.guests),
    nights: carried(nights, this.nights),
    amenities: amenities ?? this.amenities,
  );

  @override
  bool operator ==(Object other) =>
      other is StayFilters &&
      other.title == title &&
      other.city == city &&
      other.type == type &&
      other.category == category &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.guests == guests &&
      other.nights == nights &&
      listEquals(other.amenities, amenities);

  @override
  int get hashCode => Object.hash(
    title,
    city,
    type,
    category,
    minPrice,
    maxPrice,
    guests,
    nights,
    Object.hashAll(amenities),
  );
}
