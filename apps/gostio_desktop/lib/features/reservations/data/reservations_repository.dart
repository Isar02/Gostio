import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/paging/page_walk.dart';
import '../../../core/time/calendar_days.dart';
import 'refund_quote.dart';
import 'reservation.dart';
import 'reservation_payment.dart';
import 'reservation_query.dart';
import 'reservation_refund.dart';

class ReservationsRepository {
  const ReservationsRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<Reservation>> search({
    required ReservationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) async {
    final JsonMap body = await _client.get(
      _root,
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        'hostId': ?hostId,
        ...query.toParameters(),
      },
    );

    return PagedResult<Reservation>.fromJson(
      body,
      (Object? item) => Reservation.fromJson(item! as JsonMap),
    );
  }

  Future<Reservation> get(int id) async =>
      Reservation.fromJson(await _client.get('$_root/$id'));

  Future<Reservation> confirm(int id) async =>
      Reservation.fromJson(await _client.post('$_root/$id/confirm'));

  Future<Reservation> cancel(int id, {required String reason}) async =>
      Reservation.fromJson(
        await _client.post(
          '$_root/$id/cancel',
          body: <String, dynamic>{'reason': reason},
        ),
      );

  // A booking nobody ever paid for and one that is owed nothing back are each
  // answered with a 404, which is an absence rather than a failure: the screen
  // says so where a row would have been instead of reporting a broken read.
  Future<ReservationPayment?> payment(int id) => _absentWhereMissing(
    () async =>
        ReservationPayment.fromJson(await _client.get('$_root/$id/payment')),
  );

  Future<ReservationRefund?> refund(int id) => _absentWhereMissing(
    () async =>
        ReservationRefund.fromJson(await _client.get('$_root/$id/refund')),
  );

  // Answered whether or not anything was charged, so a booking can be called
  // off knowing what that costs.
  Future<RefundQuote> refundQuote(int id) async =>
      RefundQuote.fromJson(await _client.get('$_root/$id/refund/quote'));

  Future<int> countForAccommodation(int accommodationId) =>
      _count(<String, dynamic>{'accommodationId': accommodationId});

  Future<int> countForExperience(int experienceId) =>
      _count(<String, dynamic>{'experienceId': experienceId});

  // Every reservation against the term, cancelled ones included: what stops a
  // term being deleted is the foreign key, which a cancellation does not undo.
  Future<int> countForSlot(int slotId) =>
      _count(<String, dynamic>{'experienceSlotId': slotId});

  // Only the count is wanted, so the smallest page the API allows is asked for
  // and the rows it answers with are thrown away.
  Future<int> _count(JsonMap matching) async {
    final JsonMap body = await _client.get(
      _root,
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
    _root,
    read: Reservation.fromJson,
    query: <String, dynamic>{
      'accommodationId': accommodationId,
      'from': CalendarDays.write(from),
      'to': CalendarDays.write(to),
    },
  );

  static Future<T?> _absentWhereMissing<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on ApiException catch (failure) {
      if (failure.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  static const String _root = '/reservations';
}
