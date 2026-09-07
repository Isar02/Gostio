import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/push/push_notice.dart';

void main() {
  test('a delivery names the booking it is about', () {
    final PushNotice notice = PushNotice.of(<String, dynamic>{
      'type': 'PaymentSucceeded',
      'reservationId': '42',
    });

    expect(notice.reservationId, 42);
  });

  // The one kind that carries no reservation sends the field as an empty
  // string, because every value in a delivery travels as one.
  test('a notice about no booking names none', () {
    final PushNotice notice = PushNotice.of(<String, dynamic>{
      'type': 'HostVerificationDecided',
      'reservationId': '',
    });

    expect(notice.reservationId, isNull);
  });

  // A delivery this build cannot read is still a tap the reader made, so it is
  // a notice that names nothing rather than one that throws.
  test('a delivery carrying nothing readable names nothing', () {
    expect(
      PushNotice.of(<String, dynamic>{'reservationId': 'not a number'})
          .reservationId,
      isNull,
    );
    expect(PushNotice.of(<String, dynamic>{}).reservationId, isNull);
  });
}
