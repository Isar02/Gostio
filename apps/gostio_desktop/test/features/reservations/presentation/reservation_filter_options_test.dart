import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_draft.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_query.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodations_repository.dart';
import 'package:gostio_desktop/features/experiences/data/experience.dart';
import 'package:gostio_desktop/features/experiences/data/experience_draft.dart';
import 'package:gostio_desktop/features/experiences/data/experience_query.dart';
import 'package:gostio_desktop/features/experiences/data/experiences_repository.dart';
import 'package:gostio_desktop/features/listings/data/listing_address.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/reservations/presentation/reservation_filter_options.dart';

import '../../../support/reference_double.dart';

void main() {
  test('both catalogues fill one list, each on its own side', () async {
    final ReservationFilterOptions options =
        await ReservationFilterOptions.load(_Reference(), _Stays(), _Terms());

    expect(options.statuses, hasLength(4));
    expect(
      options.listings.map((BookedListing booked) => booked.address),
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
    final _Stays stays = _Stays();
    final _Terms terms = _Terms();

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

class _Stays implements AccommodationsRepository {
  final List<int?> hostIds = <int?>[];

  @override
  Future<List<LookupItem>> titles({int? hostId}) async {
    hostIds.add(hostId);

    return const <LookupItem>[
      LookupItem(id: 4, name: 'Stone villa on the hill above Neum'),
    ];
  }

  @override
  Future<Accommodation> get(int id) => throw UnimplementedError();

  @override
  Future<Accommodation> create(AccommodationDraft draft, {int? hostId}) =>
      throw UnimplementedError();

  @override
  Future<Accommodation> update(
    int id,
    AccommodationDraft draft, {
    required bool isActive,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();

  @override
  Future<PagedResult<Accommodation>> search({
    required AccommodationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) => throw UnimplementedError();
}

class _Terms implements ExperiencesRepository {
  final List<int?> hostIds = <int?>[];

  @override
  Future<List<LookupItem>> titles({int? hostId}) async {
    hostIds.add(hostId);

    return const <LookupItem>[
      LookupItem(id: 12, name: 'Rafting the Neretva canyon'),
    ];
  }

  @override
  Future<Experience> get(int id) => throw UnimplementedError();

  @override
  Future<Experience> create(ExperienceDraft draft, {int? hostId}) =>
      throw UnimplementedError();

  @override
  Future<Experience> update(
    int id,
    ExperienceDraft draft, {
    required bool isActive,
  }) => throw UnimplementedError();

  @override
  Future<void> delete(int id) => throw UnimplementedError();

  @override
  Future<PagedResult<Experience>> search({
    required ExperienceQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) => throw UnimplementedError();
}
