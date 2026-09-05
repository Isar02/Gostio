import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/live_notifier.dart';
import '../data/card_sheet.dart';
import '../data/payment_repository.dart';

// Where paying has got to. Paid is not among these on purpose: it is read off
// the booking the server answered and never off what the sheet reported.
enum PaymentStage { idle, opening, confirming, unconfirmed }

// Paying for one booking. The sheet closing is not the payment — the payment
// is the signed call the processor makes to the server — so what the sheet
// answers only decides whether the booking is worth reading back.
class PaymentNotifier extends LiveNotifier {
  PaymentNotifier(
    this._payments,
    this._sheet,
    this._booking, {
    Duration? between,
  }) : _between = between ?? _pause;

  // How long a confirmation is left to arrive before the booking is read
  // again, and how many times it is worth asking: enough to cover a processor
  // taking its time, and few enough that a reader is told something rather
  // than left watching a spinner.
  static const Duration _pause = Duration(seconds: 2);
  static const int _tries = 10;

  final PaymentRepository _payments;
  final CardSheet _sheet;
  final Duration _between;

  Reservation _booking;
  PaymentStage _stage = PaymentStage.idle;
  String? _refusal;
  bool _holdRanOut = false;

  Reservation get booking => _booking;

  PaymentStage get stage => _stage;

  String? get refusal => _refusal;

  bool get isPaid => _booking.isPaid;

  // A hold that has run out no longer holds a place, and the server refuses
  // the charge. A button that has to be pressed to learn that is a button
  // that lied, so the countdown says when it goes.
  bool get isPayable => !isPaid && !_holdRanOut && _stage == PaymentStage.idle;

  void holdRanOut() {
    if (_holdRanOut) {
      return;
    }

    _holdRanOut = true;
    publish();
  }

  Future<void> pay() async {
    if (!isPayable) {
      return;
    }

    _moveTo(PaymentStage.opening);

    final ReservationPayment charge;
    try {
      charge = await _payments.start(_booking.id);
    } on ApiException catch (refused) {
      _moveTo(PaymentStage.idle, refusal: refused.message);

      return;
    }

    if (isDisposed) {
      return;
    }

    final String? key = charge.publishableKey;
    final String? secret = charge.clientSecret;
    if (key == null || secret == null) {
      _moveTo(
        PaymentStage.idle,
        refusal: 'This charge cannot be opened for payment.',
      );

      return;
    }

    final CardSheetResult answer = await _sheet.present(
      publishableKey: key,
      clientSecret: secret,
    );

    if (isDisposed) {
      return;
    }

    switch (answer) {
      case CardSheetCancelled():
        _moveTo(PaymentStage.idle);
      case CardSheetRefused(:final String message):
        _moveTo(PaymentStage.idle, refusal: message);
      case CardSheetSent():
        await _confirm();
    }
  }

  // The reader was told the confirmation had not arrived. Asking again reads
  // the booking rather than charging anything: the card was already sent.
  Future<void> confirmAgain() async {
    if (_stage == PaymentStage.unconfirmed) {
      await _confirm();
    }
  }

  // The booking is read back until it says it is paid, for a bounded number of
  // tries. A read that is refused is not a payment that failed, so the next
  // try asks again and only running out of them is reported.
  Future<void> _confirm() async {
    _moveTo(PaymentStage.confirming);

    for (int attempt = 0; attempt < _tries; attempt++) {
      await Future<void>.delayed(_between);
      if (isDisposed) {
        return;
      }

      try {
        final Reservation read = await _payments.booking(_booking.id);
        if (isDisposed) {
          return;
        }

        _booking = read;
        if (read.isPaid) {
          _moveTo(PaymentStage.idle);

          return;
        }
      } on ApiException {
        continue;
      }
    }

    _moveTo(PaymentStage.unconfirmed);
  }

  void _moveTo(PaymentStage stage, {String? refusal}) {
    _stage = stage;
    _refusal = refusal;
    publish();
  }
}
