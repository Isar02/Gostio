import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_query.dart';

void main() {
  test('a filter nobody set is left out of the request', () {
    const AccommodationQuery query = AccommodationQuery();

    expect(query.toParameters(), isEmpty);
    expect(query.isEmpty, isTrue);
  });

  test('a title of blank space is not a title to match', () {
    const AccommodationQuery query = AccommodationQuery(title: '   ');

    expect(query.toParameters(), isEmpty);
  });

  test('a title reaches the request trimmed', () {
    const AccommodationQuery query = AccommodationQuery(title: '  Villa  ');

    expect(query.toParameters(), <String, dynamic>{'title': 'Villa'});
  });

  test('every filter that was set reaches the request', () {
    const AccommodationQuery query = AccommodationQuery(
      title: 'Villa',
      cityId: 3,
      accommodationTypeId: 4,
      accommodationCategoryId: 5,
      minPrice: 40,
      maxPrice: 120.5,
      minGuests: 2,
      amenityIds: <int>[7, 9],
      isActive: false,
    );

    expect(query.toParameters(), <String, dynamic>{
      'title': 'Villa',
      'cityId': 3,
      'accommodationTypeId': 4,
      'accommodationCategoryId': 5,
      'minPrice': 40.0,
      'maxPrice': 120.5,
      'minGuests': 2,
      'isActive': false,
      'amenityIds': <int>[7, 9],
    });
    expect(query.isEmpty, isFalse);
  });

  test('an empty amenity list is not a set of amenities to match', () {
    const AccommodationQuery query = AccommodationQuery(
      amenityIds: <int>[],
      minGuests: 2,
    );

    expect(query.toParameters().containsKey('amenityIds'), isFalse);
  });
}
