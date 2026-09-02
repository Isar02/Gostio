import 'package:gostio_desktop/features/reviews/data/review.dart';

// A review of a stay, which is the shape most of these tests read. What a
// test is about it names itself; the rest is a plausible row from the seed.
Review review({
  int id = 1,
  int reservationId = 31,
  String guestName = 'Ana Marić',
  String listingTitle = 'Stone villa on the hill above Neum',
  int rating = 5,
  String? comment = 'The terrace over the bay was worth the drive.',
  int? accommodationId = 4,
  int? experienceId,
  DateTime? modifiedAt,
}) => Review(
  id: id,
  reservationId: reservationId,
  guestId: 21,
  guestName: guestName,
  listingTitle: listingTitle,
  rating: rating,
  comment: comment,
  accommodationId: accommodationId,
  experienceId: experienceId,
  createdAt: DateTime.utc(2026, 8, 24, 18, 40),
  modifiedAt: modifiedAt,
);
