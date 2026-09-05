import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/calendar/day_window.dart';
import 'listing_filters.dart';

// What a guest is asking the experience catalogue. Where the stay side filters
// on nights that have to be free, this one filters on a term that is still
// open: a window of days, and how many places have to be left on it.
@immutable
class ExperienceFilters implements ListingFilters<ExperienceFilters> {
  const ExperienceFilters({
    this.title,
    this.city,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.places,
    this.longestMinutes,
    this.days,
  });

  @override
  final String? title;

  final LookupItem? city;
  final LookupItem? category;
  final double? minPrice;
  final double? maxPrice;
  final int? places;
  final int? longestMinutes;
  final DayWindow? days;

  bool get isFiltered => applied.isNotEmpty;

  @override
  ExperienceFilters get cleared => ExperienceFilters(title: title);

  @override
  ExperienceFilters searchingFor(String? title) =>
      replacing(title: written(title));

  @override
  List<AppliedFilter<ExperienceFilters>> get applied =>
      <AppliedFilter<ExperienceFilters>>[
        if (days case final DayWindow days)
          AppliedFilter<ExperienceFilters>(
            days.isOneDay
                ? AppDates.day(days.from)
                : '${AppDates.day(days.from)} to ${AppDates.day(days.to)}',
            replacing(days: null),
          ),
        if (city case final LookupItem city)
          AppliedFilter<ExperienceFilters>(city.name, replacing(city: null)),
        if (places case final int places)
          AppliedFilter<ExperienceFilters>(
            '$places ${places == 1 ? "place" : "places"}',
            replacing(places: null),
          ),
        if (priceLabel(minPrice, maxPrice) case final String label)
          AppliedFilter<ExperienceFilters>(
            label,
            replacing(minPrice: null, maxPrice: null),
          ),
        if (category case final LookupItem category)
          AppliedFilter<ExperienceFilters>(
            category.name,
            replacing(category: null),
          ),
        if (longestMinutes case final int minutes)
          AppliedFilter<ExperienceFilters>(
            'Up to ${AppDurations.inWords(minutes)}',
            replacing(longestMinutes: null),
          ),
      ];

  @override
  JsonMap toParameters() => <String, dynamic>{
    // Explore is what a guest can book, so a withdrawn listing its host may
    // still read is not one of the answers here.
    'isActive': true,
    'title': ?written(title),
    'cityId': ?city?.id,
    'experienceCategoryId': ?category?.id,
    'minPrice': ?minPrice,
    'maxPrice': ?maxPrice,
    'maxDurationMinutes': ?longestMinutes,
    'places': ?places,
    // The API matches the moment a term starts, so a window of days closes on
    // the last instant of the day chosen rather than on that day's midnight.
    if (days case final DayWindow days) ...<String, dynamic>{
      'availableFrom': Instants.write(days.from),
      'availableTo': Instants.endOfDay(days.to),
    },
  };

  ExperienceFilters replacing({
    Object? title = unchanged,
    Object? city = unchanged,
    Object? category = unchanged,
    Object? minPrice = unchanged,
    Object? maxPrice = unchanged,
    Object? places = unchanged,
    Object? longestMinutes = unchanged,
    Object? days = unchanged,
  }) => ExperienceFilters(
    title: carried(title, this.title),
    city: carried(city, this.city),
    category: carried(category, this.category),
    minPrice: carried(minPrice, this.minPrice),
    maxPrice: carried(maxPrice, this.maxPrice),
    places: carried(places, this.places),
    longestMinutes: carried(longestMinutes, this.longestMinutes),
    days: carried(days, this.days),
  );

  @override
  bool operator ==(Object other) =>
      other is ExperienceFilters &&
      other.title == title &&
      other.city == city &&
      other.category == category &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.places == places &&
      other.longestMinutes == longestMinutes &&
      other.days == days;

  @override
  int get hashCode => Object.hash(
    title,
    city,
    category,
    minPrice,
    maxPrice,
    places,
    longestMinutes,
    days,
  );
}
