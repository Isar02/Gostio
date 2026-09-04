import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../accommodations/data/accommodations_repository.dart';
import '../../experiences/data/experiences_repository.dart';
import '../../listings/data/listing_choice.dart';
import '../../reference/data/reference_repository.dart';

@immutable
class ReservationFilterOptions {
  const ReservationFilterOptions({
    required this.statuses,
    required this.listings,
  });

  static const ReservationFilterOptions none = ReservationFilterOptions(
    statuses: <LookupItem>[],
    listings: <ListingChoice>[],
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
      listings: ListingChoice.across(
        accommodations: tables[1],
        experiences: tables[2],
      ),
    );
  }

  final List<LookupItem> statuses;

  final List<ListingChoice> listings;
}
