import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/features/listings/data/listing_address.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';
import 'package:gostio_desktop/features/reservations/data/reservation_query.dart';
import 'package:gostio_desktop/features/reservations/presentation/reservations_notifier.dart';

import '../../../support/booking_fixture.dart';
import '../../../support/bookings_double.dart';

void main() {
  test('the platform is asked for without a host', () async {
    final _Bookings repository = _Bookings();
    final ReservationsNotifier notifier = ReservationsNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.reload();

    expect(repository.hostIds, <int?>[null]);
  });

  test(
    'clearing the filters does not clear the host the list is for',
    () async {
      final _Bookings repository = _Bookings();
      final ReservationsNotifier notifier = ReservationsNotifier(
        repository,
        hostId: 7,
      );
      addTearDown(notifier.dispose);

      await notifier.apply(const ReservationQuery(reservationStatusId: 2));
      await notifier.apply(const ReservationQuery());

      expect(repository.hostIds, <int?>[7, 7]);
      expect(repository.queries.last.toParameters(), isEmpty);
    },
  );

  test('a filter is applied from the first page', () async {
    final _Bookings repository = _Bookings(totalCount: 60);
    final ReservationsNotifier notifier = ReservationsNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.openPage(3);
    await notifier.apply(
      const ReservationQuery(
        listing: ListingAddress(ListingKind.accommodation, 4),
      ),
    );

    expect(notifier.page, 1);
    expect(repository.pages, <int>[3, 1]);
  });
}

class _Bookings extends BookingsDouble {
  _Bookings({this.totalCount = 1});

  final int totalCount;
  final List<int?> hostIds = <int?>[];
  final List<int> pages = <int>[];
  final List<ReservationQuery> queries = <ReservationQuery>[];

  @override
  Future<PagedResult<Reservation>> search({
    required ReservationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) async {
    hostIds.add(hostId);
    pages.add(page);
    queries.add(query);

    return PagedResult<Reservation>(
      items: <Reservation>[booking()],
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }
}
