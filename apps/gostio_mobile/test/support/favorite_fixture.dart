import 'package:gostio_core/gostio_core.dart';

// A saved listing the way the favourites route answers one. A test names only
// what it is about; the rest is a plausible row from the seed.
Favorite favorite({
  int id = 1,
  int? accommodationId = 4,
  int? experienceId,
  String listingTitle = 'Old town loft with a Baščaršija view',
  String cityName = 'Sarajevo',
  double price = 160,
  int? coverPhotoId,
  bool isListingActive = true,
}) => Favorite(
  id: id,
  accommodationId: accommodationId,
  experienceId: experienceId,
  listingTitle: listingTitle,
  cityName: cityName,
  countryName: 'Bosnia and Herzegovina',
  price: price,
  coverPhotoId: coverPhotoId,
  isListingActive: isListingActive,
  createdAt: DateTime.utc(2026, 8, 20, 10),
);

List<Favorite> favorites(int count) => <Favorite>[
  for (int index = 1; index <= count; index++)
    favorite(
      id: index,
      accommodationId: index,
      listingTitle: 'Listing $index',
      price: 100 + index.toDouble(),
    ),
];
