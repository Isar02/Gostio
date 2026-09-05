import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/payment/data/card_sheet.dart';
import 'package:gostio_mobile/features/payment/presentation/payment_notifier.dart';

import '../../../support/booking_fixture.dart';
import '../../../support/payment_double.dart';

void main() {
  PaymentNotifier paying(
    PaymentDouble payments,
    CardSheetDouble sheet, {
    Reservation? booking,
  }) => PaymentNotifier(
    payments,
    sheet,
    booking ?? stayBooking(),
    between: Duration.zero,
  );

  test('the sheet is opened on what the charge came back with', () async {
    final PaymentDouble payments = PaymentDouble(
      reads: <Reservation>[stayBooking(isPaid: true)],
    );
    final CardSheetDouble sheet = CardSheetDouble();

    await paying(payments, sheet).pay();

    expect(payments.started, <int>[501]);
    expect(sheet.presented.single.clientSecret, 'pi_1_secret_9');
    expect(sheet.presented.single.publishableKey, 'pk_test_9');
  });

  // Closing the sheet is not a fault, and there is nothing to confirm.
  test('a sheet the reader closed leaves the booking as it was', () async {
    final PaymentDouble payments = PaymentDouble();
    final PaymentNotifier payment = paying(
      payments,
      CardSheetDouble(answer: const CardSheetCancelled()),
    );

    await payment.pay();

    expect(payment.stage, PaymentStage.idle);
    expect(payment.refusal, isNull);
    expect(payment.isPayable, isTrue);
    expect(payments.reread, isEmpty);
  });

  test('a sheet the processor could not open says what it said', () async {
    final PaymentNotifier payment = paying(
      PaymentDouble(),
      CardSheetDouble(
        answer: const CardSheetRefused('The card sheet could not be opened.'),
      ),
    );

    await payment.pay();

    expect(payment.refusal, 'The card sheet could not be opened.');
    expect(payment.stage, PaymentStage.idle);
  });

  test('a charge the server refused says what the server said', () async {
    final PaymentDouble payments = PaymentDouble(
      startFailure: const ApiException(
        message: 'This reservation has already been paid for.',
        statusCode: 400,
      ),
    );
    final CardSheetDouble sheet = CardSheetDouble();
    final PaymentNotifier payment = paying(payments, sheet);

    await payment.pay();

    expect(payment.refusal, 'This reservation has already been paid for.');
    expect(sheet.presented, isEmpty);
  });

  // The one rule this screen may not get wrong: the sheet reporting success is
  // not the payment. Paid is what the server answered.
  test('paid is read off the booking rather than off the sheet', () async {
    final PaymentDouble payments = PaymentDouble(
      reads: <Reservation>[stayBooking(), stayBooking(isPaid: true)],
    );
    final PaymentNotifier payment = paying(payments, CardSheetDouble());

    await payment.pay();

    expect(payments.reread, <int>[501, 501]);
    expect(payment.isPaid, isTrue);
    expect(payment.stage, PaymentStage.idle);
    expect(payment.isPayable, isFalse);
  });

  test('a payment nothing confirms is said to be unconfirmed', () async {
    final PaymentDouble payments = PaymentDouble();
    final PaymentNotifier payment = paying(payments, CardSheetDouble());

    await payment.pay();

    expect(payment.stage, PaymentStage.unconfirmed);
    expect(payment.isPaid, isFalse);
    expect(payments.reread, hasLength(10));
  });

  // A booking that could not be read is not a card that was refused.
  test('a refused read is not reported as a refused payment', () async {
    final PaymentDouble payments = PaymentDouble(
      readFailure: const ApiException(message: 'Offline', statusCode: 503),
    );
    final PaymentNotifier payment = paying(payments, CardSheetDouble());

    await payment.pay();

    expect(payment.stage, PaymentStage.unconfirmed);
    expect(payment.refusal, isNull);
    expect(payments.reread, hasLength(10));
  });

  test(
    'asking again reads the booking without opening a second sheet',
    () async {
      final PaymentDouble payments = PaymentDouble();
      final CardSheetDouble sheet = CardSheetDouble();
      final PaymentNotifier payment = paying(payments, sheet);

      await payment.pay();
      payments.reread.clear();
      await payment.confirmAgain();

      expect(sheet.presented, hasLength(1));
      expect(payments.reread, hasLength(10));
      expect(payment.stage, PaymentStage.unconfirmed);
    },
  );

  test('a hold that ran out is not offered a payment', () async {
    final PaymentDouble payments = PaymentDouble();
    final PaymentNotifier payment = paying(payments, CardSheetDouble());

    payment.holdRanOut();
    await payment.pay();

    expect(payment.isPayable, isFalse);
    expect(payments.started, isEmpty);
  });
}
