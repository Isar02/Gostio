import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/listing/data/listing_detail.dart';

import '../../../support/listing_fixture.dart';

void main() {
  test('a stay answers as the accommodation it was read from', () {
    final ListingDetail detail = StayDetail(
      stay(id: 7, title: 'Loft over the river', cityName: 'Mostar'),
    );

    expect(detail.address, const ListingAddress(ListingKind.accommodation, 7));
    expect(detail.title, 'Loft over the river');
    expect(detail.place, 'Mostar, Bosnia and Herzegovina');
    expect(detail.where, 'Maršala Tita 14');
    expect(detail.price, 90);
    expect(detail.priceUnit, 'per night');
  });

  // A term is sold by the place rather than by the night, and it is attended
  // somewhere rather than lived in, so the two say different things in the
  // same two fields.
  test('a term answers as the experience it was read from', () {
    final ListingDetail detail = ExperienceDetail(
      experience(id: 4, title: 'Rafting the Neretva'),
    );

    expect(detail.address, const ListingAddress(ListingKind.experience, 4));
    expect(detail.where, 'Sebilj');
    expect(detail.price, 25);
    expect(detail.priceUnit, 'per person');
  });

  test('the heart a listing was read with comes from the row', () {
    expect(StayDetail(stay()).isFavorite, isFalse);
    expect(StayDetail(stay(isFavorite: true)).isFavorite, isTrue);
    expect(ExperienceDetail(experience(isFavorite: true)).isFavorite, isTrue);
  });
}
