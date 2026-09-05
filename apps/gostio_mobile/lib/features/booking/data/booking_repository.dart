import 'package:gostio_core/gostio_core.dart';

import '../../../core/calendar/date_range.dart';

// What a guest does to book: read the terms an experience still has open, ask
// which of them they are already on, and write the booking itself.
//
// The booking that comes back carries its own hold and its own total. Nothing
// here works either of them out: this sends dates or a term and a head count,
// and renders what the server answers.
class BookingRepository {
  const BookingRepository(this._client);

  final ApiClient _client;

  static const String _reservations = '/reservations';

  Future<Reservation> bookStay({
    required int accommodationId,
    required DateRange dates,
    required int guestCount,
  }) => _create(<String, dynamic>{
    'accommodationId': accommodationId,
    'checkInDate': CalendarDays.write(dates.from),
    'checkOutDate': CalendarDays.write(dates.to),
    'guestCount': guestCount,
  });

  Future<Reservation> bookTerm({
    required int slotId,
    required int guestCount,
  }) => _create(<String, dynamic>{
    'experienceSlotId': slotId,
    'guestCount': guestCount,
  });

  // The terms still ahead, earliest first as the server orders them. One that
  // has begun cannot be booked and one the host has closed is not offered, so
  // neither is asked for.
  Future<PagedResult<ExperienceSlot>> terms(
    int experienceId, {
    required int page,
    required int pageSize,
  }) async {
    final JsonMap body = await _client.get(
      '${ListingKind.experience.root}/$experienceId/slots',
      query: <String, dynamic>{
        'from': Instants.write(DateTime.now()),
        'isActive': true,
        'page': page,
        'pageSize': pageSize,
      },
    );

    return PagedResult<ExperienceSlot>.fromJson(
      body,
      (Object? item) => ExperienceSlot.fromJson(item! as JsonMap),
    );
  }

  // The terms of this experience the reader is already on. A guest holds one
  // place on a term and no more, and a screen that did not know this would
  // offer a second booking the server is about to refuse.
  //
  // The account is not named in the request because it cannot be anybody else:
  // reservations answer the guest who booked and the host who was booked, and
  // a host does not book their own experience.
  Future<Set<int>> termsAlreadyHeld(int experienceId) async {
    final List<Reservation> held = await readEveryPage<Reservation>(
      _client,
      _reservations,
      read: Reservation.fromJson,
      query: <String, dynamic>{
        'experienceId': experienceId,
        // Active is the server's own word for a booking that still holds its
        // place, which is exactly what stands in the way of a second one.
        'isActive': true,
      },
    );

    return held
        .map((Reservation booking) => booking.experienceSlotId)
        .whereType<int>()
        .toSet();
  }

  Future<Reservation> _create(JsonMap body) async =>
      Reservation.fromJson(await _client.post(_reservations, body: body));
}
