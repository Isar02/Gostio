import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

Favorite saved({
  int? accommodationId,
  int? experienceId,
  int? coverPhotoId,
  bool isListingActive = true,
}) => Favorite(
  id: 4,
  accommodationId: accommodationId,
  experienceId: experienceId,
  listingTitle: 'Stone villa on the hill above Neum',
  cityName: 'Neum',
  countryName: 'Bosnia and Herzegovina',
  price: 240,
  coverPhotoId: coverPhotoId,
  isListingActive: isListingActive,
  createdAt: DateTime.utc(2026, 8, 2, 9),
);

void main() {
  test('a row is addressed by whichever catalogue it names', () {
    expect(
      saved(accommodationId: 7).listing,
      const ListingAddress(ListingKind.accommodation, 7),
    );
    expect(
      saved(experienceId: 7).listing,
      const ListingAddress(ListingKind.experience, 7),
    );
  });

  test('a row naming neither catalogue is not a listing to address', () {
    expect(saved().listing, isNull);
    expect(saved(coverPhotoId: 3).coverPath, isNull);
  });

  test('the cover is named against the listing that holds it', () {
    expect(
      saved(experienceId: 12, coverPhotoId: 3).coverPath,
      '/experiences/12/photos/3/content',
    );
    expect(saved(accommodationId: 12).coverPath, isNull);
  });

  test('a withdrawn listing is still saved and says it has gone', () {
    expect(
      saved(accommodationId: 7, isListingActive: false).listing,
      isNotNull,
    );
    expect(
      saved(accommodationId: 7, isListingActive: false).isListingActive,
      isFalse,
    );
  });
}
