import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

void main() {
  test('each catalogue keeps its own root under the same shape', () {
    const ListingAddress accommodation = ListingAddress(
      ListingKind.accommodation,
      7,
    );
    const ListingAddress experience = ListingAddress(ListingKind.experience, 7);

    expect(accommodation.photos, '/accommodations/7/photos');
    expect(experience.photos, '/experiences/7/photos');
  });

  test('a photograph and its bytes hang off the listing that holds it', () {
    const ListingAddress listing = ListingAddress(ListingKind.experience, 12);

    expect(listing.photo(4), '/experiences/12/photos/4');
    expect(listing.photoContent(4), '/experiences/12/photos/4/content');
  });

  test('two addresses for the same listing are the same address', () {
    expect(
      const ListingAddress(ListingKind.accommodation, 3),
      const ListingAddress(ListingKind.accommodation, 3),
    );
    expect(
      const ListingAddress(ListingKind.accommodation, 3),
      isNot(const ListingAddress(ListingKind.experience, 3)),
    );
  });
}
