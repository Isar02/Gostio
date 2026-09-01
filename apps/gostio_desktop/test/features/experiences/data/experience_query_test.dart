import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/experiences/data/experience_query.dart';

void main() {
  test('a filter nobody set is left out of the request', () {
    const ExperienceQuery query = ExperienceQuery();

    expect(query.toParameters(), isEmpty);
    expect(query.isEmpty, isTrue);
  });

  test('a title of blank space is not a title to match', () {
    const ExperienceQuery query = ExperienceQuery(title: '   ');

    expect(query.toParameters(), isEmpty);
  });

  test('a title reaches the request trimmed', () {
    const ExperienceQuery query = ExperienceQuery(title: '  Rafting  ');

    expect(query.toParameters(), <String, dynamic>{'title': 'Rafting'});
  });

  test('every filter that was set reaches the request', () {
    const ExperienceQuery query = ExperienceQuery(
      title: 'Rafting',
      cityId: 3,
      experienceCategoryId: 5,
      minPrice: 40,
      maxPrice: 120.5,
      maxDurationMinutes: 240,
      isActive: false,
    );

    expect(query.toParameters(), <String, dynamic>{
      'title': 'Rafting',
      'cityId': 3,
      'experienceCategoryId': 5,
      'minPrice': 40.0,
      'maxPrice': 120.5,
      'maxDurationMinutes': 240,
      'isActive': false,
    });
    expect(query.isEmpty, isFalse);
  });

  test('two queries that ask the same thing are the same query', () {
    expect(
      const ExperienceQuery(cityId: 3, maxDurationMinutes: 90),
      const ExperienceQuery(cityId: 3, maxDurationMinutes: 90),
    );
    expect(
      const ExperienceQuery(cityId: 3),
      isNot(const ExperienceQuery(cityId: 4)),
    );
  });
}
