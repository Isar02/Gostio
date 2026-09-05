import 'package:gostio_core/gostio_core.dart';

// What paying for a booking needs of the server: the charge to open a card
// sheet on, and the booking itself read back afterwards.
//
// The booking is here rather than beside the one that made it because paid is
// recorded on the booking and nowhere else. Nothing in this client writes it.
class PaymentRepository {
  const PaymentRepository(this._client);

  final ApiClient _client;

  // Asking twice is safe: a settled booking refuses a second charge and an
  // open one answers with the charge it already has, so a sheet that was
  // closed is opened again rather than duplicated.
  Future<ReservationPayment> start(int reservationId) async =>
      ReservationPayment.fromJson(
        await _client.post('/reservations/$reservationId/payment'),
      );

  Future<Reservation> booking(int reservationId) async =>
      Reservation.fromJson(await _client.get('/reservations/$reservationId'));
}
