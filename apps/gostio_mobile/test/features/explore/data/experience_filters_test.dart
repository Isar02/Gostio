import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/calendar/day_window.dart';
import 'package:gostio_mobile/features/explore/data/experience_filters.dart';
import 'package:gostio_mobile/features/explore/data/listing_filters.dart';

void main() {
  const LookupItem sarajevo = LookupItem(id: 1, name: 'Sarajevo');
  const LookupItem food = LookupItem(id: 6, name: 'Food');

  test('a search nobody has narrowed still asks only for what is on offer', () {
    expect(const ExperienceFilters().toParameters(), <String, dynamic>{
      'isActive': true,
    });
  });

  test('a filter nobody set is left out rather than sent empty', () {
    final JsonMap sent = const ExperienceFilters(
      category: food,
      places: 2,
    ).toParameters();

    expect(sent['experienceCategoryId'], 6);
    expect(sent['places'], 2);
    expect(sent.containsKey('maxDurationMinutes'), isFalse);
    expect(sent.containsKey('availableFrom'), isFalse);
  });

  // The API matches the moment a term starts, so a window of days has to reach
  // the last instant of the day it closes on or the terms that afternoon are
  // outside the search the reader made.
  test('a window of days closes on the last instant of its last day', () {
    final JsonMap sent = ExperienceFilters(
      days: DayWindow(from: DateTime(2026, 6, 12), to: DateTime(2026, 6, 14)),
    ).toParameters();

    expect(sent['availableFrom'], Instants.write(DateTime(2026, 6, 12)));
    expect(sent['availableTo'], Instants.endOfDay(DateTime(2026, 6, 14)));
  });

  test('a window over one day is still both ends of a search', () {
    final JsonMap sent = ExperienceFilters(
      days: DayWindow.onOneDay(DateTime(2026, 6, 12)),
    ).toParameters();

    expect(sent['availableFrom'], Instants.write(DateTime(2026, 6, 12)));
    expect(sent['availableTo'], Instants.endOfDay(DateTime(2026, 6, 12)));
  });

  test('a chip over one day names the day rather than a run of them', () {
    final ExperienceFilters filters = ExperienceFilters(
      days: DayWindow.onOneDay(DateTime(2026, 6, 12)),
    );

    expect(filters.applied.single.label, '12 Jun 2026');
  });

  test('a chip over several days names both of its ends', () {
    final ExperienceFilters filters = ExperienceFilters(
      days: DayWindow(from: DateTime(2026, 6, 12), to: DateTime(2026, 6, 14)),
    );

    expect(filters.applied.single.label, '12 Jun 2026 to 14 Jun 2026');
  });

  test('a length is named in hours rather than in the minutes sent', () {
    const ExperienceFilters filters = ExperienceFilters(longestMinutes: 180);

    expect(filters.applied.single.label, 'Up to 3 h');
    expect(filters.toParameters()['maxDurationMinutes'], 180);
  });

  test('every filter in force is one chip', () {
    final ExperienceFilters filters = ExperienceFilters(
      title: 'walk',
      city: sarajevo,
      category: food,
      places: 2,
      maxPrice: 40,
      longestMinutes: 240,
      days: DayWindow.onOneDay(DateTime(2026, 6, 12)),
    );

    expect(
      filters.applied.map(
        (AppliedFilter<ExperienceFilters> chip) => chip.label,
      ),
      <String>[
        '12 Jun 2026',
        'Sarajevo',
        '2 places',
        'Up to ${AppNumbers.money(40)}',
        'Food',
        'Up to 4 h',
      ],
    );
  });

  test('a chip taken off leaves the rest of the search alone', () {
    const ExperienceFilters filters = ExperienceFilters(
      title: 'walk',
      city: sarajevo,
      places: 2,
    );
    final AppliedFilter<ExperienceFilters> chip = filters.applied.firstWhere(
      (AppliedFilter<ExperienceFilters> filter) => filter.label == '2 places',
    );

    expect(
      chip.without,
      const ExperienceFilters(title: 'walk', city: sarajevo),
    );
  });

  test('clearing the filters keeps the words the reader typed', () {
    const ExperienceFilters filters = ExperienceFilters(
      title: 'walk',
      city: sarajevo,
    );

    expect(filters.cleared, const ExperienceFilters(title: 'walk'));
  });
}
