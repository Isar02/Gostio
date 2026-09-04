import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../accommodations/data/accommodations_repository.dart';
import '../../experiences/data/experiences_repository.dart';
import '../../listings/data/listing_choice.dart';

// The one filter filled from a table.
@immutable
class ReviewFilterOptions {
  const ReviewFilterOptions({required this.listings});

  static const ReviewFilterOptions none = ReviewFilterOptions(
    listings: <ListingChoice>[],
  );

  static Future<ReviewFilterOptions> load(
    AccommodationsRepository accommodations,
    ExperiencesRepository experiences,
  ) async {
    final List<List<LookupItem>> catalogues = await Future.wait(
      <Future<List<LookupItem>>>[accommodations.titles(), experiences.titles()],
    );

    return ReviewFilterOptions(
      listings: ListingChoice.across(
        accommodations: catalogues[0],
        experiences: catalogues[1],
      ),
    );
  }

  final List<ListingChoice> listings;
}
