import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/payment/data/card_sheet.dart';
import 'package:gostio_mobile/features/payment/data/payment_repository.dart';

import 'booking_fixture.dart';

// A charge answered without a processor. The bookings it hands back are read
// in order, so a test says how many reads it takes before one comes back paid.
class PaymentDouble implements PaymentRepository {
  PaymentDouble({
    ReservationPayment? charge,
    List<Reservation>? reads,
    this.startFailure,
    this.readFailure,
  }) : charge = charge ?? openCharge(),
       _reads = reads ?? <Reservation>[];

  final ReservationPayment charge;
  final ApiException? startFailure;
  final ApiException? readFailure;

  final List<int> started = <int>[];
  final List<int> reread = <int>[];

  final List<Reservation> _reads;

  @override
  Future<ReservationPayment> start(int reservationId) async {
    started.add(reservationId);

    if (startFailure case final ApiException refused) {
      throw refused;
    }

    return charge;
  }

  @override
  Future<Reservation> booking(int reservationId) async {
    reread.add(reservationId);

    if (readFailure case final ApiException refused) {
      throw refused;
    }

    return _reads.isEmpty ? stayBooking() : _reads.removeAt(0);
  }
}

// The card sheet without a card sheet. It answers what it was built with and
// records that it was opened, which is all a screen above it can observe.
class CardSheetDouble implements CardSheet {
  CardSheetDouble({
    this.answer = const CardSheetSent(),
    this.holdsTheSheet = false,
  });

  final CardSheetResult answer;
  final bool holdsTheSheet;

  final List<({String publishableKey, String clientSecret})> presented =
      <({String publishableKey, String clientSecret})>[];

  final Completer<void> _closed = Completer<void>();

  void close() => _closed.complete();

  @override
  Future<CardSheetResult> present({
    required String publishableKey,
    required String clientSecret,
  }) async {
    presented.add((publishableKey: publishableKey, clientSecret: clientSecret));

    if (holdsTheSheet) {
      await _closed.future;
    }

    return answer;
  }
}
