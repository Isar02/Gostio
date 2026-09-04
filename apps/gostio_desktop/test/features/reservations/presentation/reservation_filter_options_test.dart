import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/listings/data/listing_choice.dart';
import 'package:gostio_desktop/features/reservations/presentation/reservation_filter_options.dart';

import '../../../support/catalogue_doubles.dart';
import '../../../support/reference_double.dart';

void main() {
  test('both catalogues fill one list, each on its own side', () async {
    final ReservationFilterOptions options =
        await ReservationFilterOptions.load(
          _Reference(),
          StaysDouble(),
          TermsDouble(),
        );

    expect(options.statuses, hasLength(4));
    expect(
      options.listings.map((ListingChoice booked) => booked.address),
      <ListingAddress>[
        const ListingAddress(ListingKind.accommodation, 4),
        const ListingAddress(ListingKind.experience, 12),
      ],
    );
    expect(options.listings.first.title, 'Stone villa on the hill above Neum');
  });

  // The host panel narrows both catalogues to the caller's own listings, so
  // the dropdown offers what they could actually have a booking against.
  test('the host scope reaches both catalogues', () async {
    final StaysDouble stays = StaysDouble();
    final TermsDouble terms = TermsDouble();

    await ReservationFilterOptions.load(_Reference(), stays, terms, hostId: 7);

    expect(stays.hostIds, <int?>[7]);
    expect(terms.hostIds, <int?>[7]);
  });
}

class _Reference extends ReferenceDouble {
  @override
  Future<List<LookupItem>> reservationStatuses() async => const <LookupItem>[
    LookupItem(id: 1, name: 'Pending'),
    LookupItem(id: 2, name: 'Confirmed'),
    LookupItem(id: 3, name: 'Cancelled'),
    LookupItem(id: 4, name: 'Completed'),
  ];
}
