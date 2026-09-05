import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../data/trip_window.dart';
import '../data/trips_repository.dart';

// One side of the split, paged like every other list on this client. It has no
// filter of its own — the window it reads is the one it was made for — so the
// query it pages under carries nothing.
//
// It does not read on being made. Only one of the two is in front at a time,
// and which of them is being looked at is the screen's to know.
abstract class TripsNotifier extends PagedNotifier<Reservation, void> {
  TripsNotifier(this._repository, this._guestId, this.window) : super(null);

  final TripsRepository _repository;
  final int _guestId;

  final TripWindow window;

  // Read when the list is first shown and not again: a reader who never looks
  // at what is behind them should not have paid for the read.
  Future<void> readOnce() =>
      hasLanded || isLoading ? Future<void>.value() : reload();

  // The booking as the screen this list opened left it — called off, or read
  // back paid. The list keeps the pages it has already read and redraws the
  // one row that changed.
  void tripChanged(Reservation booking) =>
      replaceWhere((Reservation held) => held.id == booking.id, booking);

  @override
  @protected
  Future<PagedResult<Reservation>> fetch({
    required int page,
    required void query,
  }) => _repository.trips(
    guestId: _guestId,
    window: window,
    page: page,
    pageSize: pageSize,
  );
}

class UpcomingTrips extends TripsNotifier {
  UpcomingTrips(TripsRepository repository, int guestId)
    : super(repository, guestId, TripWindow.upcoming);
}

class PastTrips extends TripsNotifier {
  PastTrips(TripsRepository repository, int guestId)
    : super(repository, guestId, TripWindow.past);
}
