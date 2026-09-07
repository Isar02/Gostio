import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

// The row the API answers, and the one field on it that a server ahead of this
// build can carry a value for.
void main() {
  test('the row names what raised it', () {
    final AppNotification notice = AppNotification.fromJson(<String, dynamic>{
      'id': 4,
      'type': 'RefundProcessed',
      'title': 'Refund on its way',
      'body': '270.00 was returned to the card you paid with.',
      'isRead': false,
      'createdAt': '2026-09-01T10:00:00Z',
      'reservationId': 12,
    });

    expect(notice.kind, NotificationKind.refundProcessed);
    expect(notice.reservationId, 12);
    expect(notice.isRead, isFalse);
  });

  // A kind added to the server after this build shipped is a row worth drawing
  // rather than a page taken down.
  test('a kind this build does not know is still a row', () {
    final AppNotification notice = AppNotification.fromJson(<String, dynamic>{
      'id': 5,
      'type': 'SomethingAddedLater',
      'title': 'Something happened',
      'body': 'And this build has not caught up with it.',
      'isRead': true,
      'createdAt': '2026-09-01T10:00:00Z',
    });

    expect(notice.kind, NotificationKind.unknown);
    expect(notice.reservationId, isNull);
  });
}
