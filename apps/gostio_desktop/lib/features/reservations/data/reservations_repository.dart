import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/paging/page_walk.dart';
import '../../../core/time/calendar_days.dart';
import 'reservation.dart';

class ReservationsRepository {
  const ReservationsRepository(this._client);

  final ApiClient _client;

  Future<int> countForAccommodation(int accommodationId) =>
      _count(<String, dynamic>{'accommodationId': accommodationId});

  // Every reservation against the term, cancelled ones included: what stops a
  // term being deleted is the foreign key, which a cancellation does not undo.
  Future<int> countForSlot(int slotId) =>
      _count(<String, dynamic>{'experienceSlotId': slotId});

  // Only the count is wanted, so the smallest page the API allows is asked for
  // and the rows it answers with are thrown away.
  Future<int> _count(JsonMap matching) async {
    final JsonMap body = await _client.get(
      '/reservations',
      query: <String, dynamic>{...matching, 'page': 1, 'pageSize': 1},
    );

    return PagedResult<Object?>.fromJson(
      body,
      (Object? item) => item,
    ).totalCount;
  }

  // The window matches on the days a booking takes up rather than on the ones
  // it was written on, so a stay reaching past either edge comes back too.
  Future<List<Reservation>> forAccommodationWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) => readEveryPage<Reservation>(
    _client,
    '/reservations',
    read: Reservation.fromJson,
    query: <String, dynamic>{
      'accommodationId': accommodationId,
      'from': CalendarDays.write(from),
      'to': CalendarDays.write(to),
    },
  );
}
