import 'package:gostio_core/gostio_core.dart';

// A review the way the API answers one. A test names only what it is about;
// the rest is a plausible row from the seed.
Review review({
  int id = 91,
  int reservationId = 501,
  int guestId = 12,
  String guestName = 'Emina Begić',
  int? accommodationId = 1,
  int? experienceId,
  String listingTitle = 'Loft over the river',
  int rating = 5,
  String? comment = 'Quiet street, and the balcony is worth the stairs.',
  DateTime? modifiedAt,
}) => Review(
  id: id,
  reservationId: reservationId,
  guestId: guestId,
  guestName: guestName,
  accommodationId: accommodationId,
  experienceId: experienceId,
  listingTitle: listingTitle,
  rating: rating,
  comment: comment,
  createdAt: DateTime.utc(2026, 8, 20, 10),
  modifiedAt: modifiedAt,
);

List<Review> reviews(int count) => <Review>[
  for (int index = 1; index <= count; index++)
    review(
      id: index,
      reservationId: 500 + index,
      listingTitle: 'Listing $index',
      rating: 1 + (index % ReviewStars.highest),
    ),
];
