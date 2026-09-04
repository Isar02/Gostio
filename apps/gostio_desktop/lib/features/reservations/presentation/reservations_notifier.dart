import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/reservation_query.dart';
import '../data/reservations_repository.dart';

class ReservationsNotifier
    extends PagedNotifier<Reservation, ReservationQuery> {
  ReservationsNotifier(this._reservations, {this.hostId})
    : super(const ReservationQuery());

  final ReservationsRepository _reservations;

  // Set in the host panel and not a filter, so clearing the filters cannot
  // take it off. Without it the API answers everything the caller may read.
  final int? hostId;

  @override
  Future<PagedResult<Reservation>> fetch({
    required int page,
    required ReservationQuery query,
  }) => _reservations.search(
    query: query,
    page: page,
    pageSize: pageSize,
    hostId: hostId,
  );
}
