import 'package:gostio_core/gostio_core.dart';

import 'trip_window.dart';

// What a guest does with a booking after it exists: read the ones they have
// made, ask what calling one off would send back, and call it off.
//
// Nothing here works an amount out. The quote is the server's reading of its
// own policy, and the row a cancellation answers is the booking as the server
// now holds it.
class TripsRepository {
  const TripsRepository(this._client);

  final ApiClient _client;

  static const String _reservations = '/reservations';

  // The guest is named rather than left to the server's wider view of what the
  // caller may see: a host reading this list has bookings against their
  // listings too, and those are their work rather than their trips.
  Future<PagedResult<Reservation>> trips({
    required int guestId,
    required TripWindow window,
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      _reservations,
      query: <String, dynamic>{
        'guestId': guestId,
        ...window.boundedOn(CalendarDays.today()),
        'page': page,
        'pageSize': pageSize,
      },
    );

    return PagedResult<Reservation>.fromJson(
      body,
      (Object? item) => Reservation.fromJson(item! as JsonMap),
    );
  }

  // Read while calling the booking off is still a choice. It moves with the
  // clock until the cancellation, so it is asked for as the sheet opens rather
  // than carried down from the list.
  Future<RefundQuote> refundQuote(int reservationId) async =>
      RefundQuote.fromJson(
        await _client.get('$_reservations/$reservationId/refund/quote'),
      );

  Future<Reservation> cancel(
    int reservationId, {
    required String reason,
  }) async => Reservation.fromJson(
    await _client.post(
      '$_reservations/$reservationId/cancel',
      body: <String, dynamic>{'reason': reason},
    ),
  );
}
