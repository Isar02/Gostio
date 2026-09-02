import 'package:flutter/foundation.dart';

import '../../accommodations/data/accommodations_repository.dart';
import '../../experiences/data/experiences_repository.dart';
import '../../listings/data/listing_address.dart';
import '../../reference/data/lookup_item.dart';
import '../../reference/data/reference_repository.dart';

// A listing to narrow by, on the side of the catalogue it belongs to: the API
// takes an accommodation and an experience separately, and a booking is
// against one of the two.
@immutable
class BookedListing {
  const BookedListing(this.kind, this.listing);

  final ListingKind kind;
  final LookupItem listing;

  ListingAddress get address => ListingAddress(kind, listing.id);

  String get title => listing.name;

  @override
  bool operator ==(Object other) =>
      other is BookedListing && other.kind == kind && other.listing == listing;

  @override
  int get hashCode => Object.hash(kind, listing);
}

@immutable
class ReservationFilterOptions {
  const ReservationFilterOptions({
    required this.statuses,
    required this.listings,
  });

  static const ReservationFilterOptions none = ReservationFilterOptions(
    statuses: <LookupItem>[],
    listings: <BookedListing>[],
  );

  // The listings are the one dropdown filled from a catalogue rather than a
  // lookup. None of the three depends on the others, so they go out together,
  // and the host scope narrows both catalogues to the caller's own.
  static Future<ReservationFilterOptions> load(
    ReferenceRepository reference,
    AccommodationsRepository accommodations,
    ExperiencesRepository experiences, {
    int? hostId,
  }) async {
    final List<List<LookupItem>> tables = await Future.wait(
      <Future<List<LookupItem>>>[
        reference.reservationStatuses(),
        accommodations.titles(hostId: hostId),
        experiences.titles(hostId: hostId),
      ],
    );

    return ReservationFilterOptions(
      statuses: tables[0],
      listings: <BookedListing>[
        for (final LookupItem stay in tables[1])
          BookedListing(ListingKind.accommodation, stay),
        for (final LookupItem term in tables[2])
          BookedListing(ListingKind.experience, term),
      ],
    );
  }

  final List<LookupItem> statuses;

  // Places to stay first, then things to do, which is the order the navigation
  // puts the two catalogues in.
  final List<BookedListing> listings;
}
