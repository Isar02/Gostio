import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_draft.dart';

void main() {
  test('creating names a host and says nothing about publishing', () {
    expect(_draft.toCreate(hostId: 7)['hostId'], 7);
    expect(_draft.toCreate(hostId: 7).containsKey('isActive'), isFalse);
  });

  test('creating without a host leaves the caller keeping the listing', () {
    expect(_draft.toCreate().containsKey('hostId'), isFalse);
  });

  test('updating says whether it is published and never renames the host', () {
    final Map<String, dynamic> written = _draft.toUpdate(isActive: false);

    expect(written['isActive'], isFalse);
    expect(written.containsKey('hostId'), isFalse);
  });

  test('both endpoints carry every field the listing owns', () {
    for (final Map<String, dynamic> written in <Map<String, dynamic>>[
      _draft.toCreate(),
      _draft.toUpdate(isActive: true),
    ]) {
      expect(written['title'], 'Villa Neum');
      expect(written['description'], 'Above the bay.');
      expect(written['accommodationTypeId'], 4);
      expect(written['accommodationCategoryId'], 2);
      expect(written['cityId'], 18);
      expect(written['address'], 'Primorska 12');
      expect(written['latitude'], 42.92);
      expect(written['longitude'], 17.61);
      expect(written['maxGuests'], 6);
      expect(written['bedrooms'], 3);
      expect(written['bathrooms'], 2);
      expect(written['pricePerNight'], 180.5);
      expect(written['cleaningFee'], 25.0);
    }
  });
}

const AccommodationDraft _draft = AccommodationDraft(
  title: 'Villa Neum',
  description: 'Above the bay.',
  accommodationTypeId: 4,
  accommodationCategoryId: 2,
  cityId: 18,
  address: 'Primorska 12',
  latitude: 42.92,
  longitude: 17.61,
  maxGuests: 6,
  bedrooms: 3,
  bathrooms: 2,
  pricePerNight: 180.5,
  cleaningFee: 25,
);
