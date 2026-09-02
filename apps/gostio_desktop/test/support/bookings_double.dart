import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/features/reservations/data/refund_quote.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';
import 'package:gostio_desktop/features/reservations/data/reservation_payment.dart';
import 'package:gostio_desktop/features/reservations/data/reservation_query.dart';
import 'package:gostio_desktop/features/reservations/data/reservation_refund.dart';
import 'package:gostio_desktop/features/reservations/data/reservations_repository.dart';

// Five screens outside the reservations feature reach this repository for one
// count each. Everything they do not ask for is refused here once rather than
// restated as a stub in every test that composes one of them, so a test that
// reaches past what it set up still fails where it stands.
class BookingsDouble implements ReservationsRepository {
  const BookingsDouble();

  @override
  Future<int> countForAccommodation(int accommodationId) =>
      throw UnimplementedError();

  @override
  Future<int> countForExperience(int experienceId) =>
      throw UnimplementedError();

  @override
  Future<int> countForSlot(int slotId) => throw UnimplementedError();

  @override
  Future<Reservation> get(int id) => throw UnimplementedError();

  @override
  Future<PagedResult<Reservation>> search({
    required ReservationQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    int? hostId,
  }) => throw UnimplementedError();

  @override
  Future<Reservation> confirm(int id) => throw UnimplementedError();

  @override
  Future<Reservation> cancel(int id, {required String reason}) =>
      throw UnimplementedError();

  @override
  Future<ReservationPayment?> payment(int id) => throw UnimplementedError();

  @override
  Future<ReservationRefund?> refund(int id) => throw UnimplementedError();

  @override
  Future<RefundQuote> refundQuote(int id) => throw UnimplementedError();

  @override
  Future<List<Reservation>> forAccommodationWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) => throw UnimplementedError();
}
