import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/notifications/presentation/notifications_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/notice_fixture.dart';
import '../../../support/notifications_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> open(
    WidgetTester tester,
    NotificationsDouble notifications,
  ) async {
    await tester.pumpWidget(
      underTest(
        const NotificationsScreen(),
        auth: AuthDouble(),
        notifications: notifications,
      ),
    );
    await tester.pumpAndSettle();
  }

  // A list twenty rows long ends below the fold, and a row that has not been
  // built is a row no finder can see.
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300);
    await tester.pumpAndSettle();
  }

  testWidgets('a notice is drawn with what raised it and when', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NotificationsDouble(
        rows: <AppNotification>[
          notice(
            title: 'Payment received',
            body: 'Your payment for the stay in Mostar went through.',
            kind: NotificationKind.paymentSucceeded,
          ),
        ],
      ),
    );

    expect(find.text('Payment received'), findsOneWidget);
    expect(
      find.text('Your payment for the stay in Mostar went through.'),
      findsOneWidget,
    );
    expect(find.text('2 h ago'), findsOneWidget);
    expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
  });

  // Unread is a state the row is read in, so it is said in a word rather than
  // in a weight alone.
  testWidgets('only what has not been read is marked unread', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NotificationsDouble(
        rows: <AppNotification>[
          notice(id: 1, title: 'Newest'),
          notice(id: 2, title: 'Older', isRead: true),
        ],
      ),
    );

    expect(find.text('Unread'), findsOneWidget);
  });

  testWidgets('an account with nothing waiting is told so', (
    WidgetTester tester,
  ) async {
    await open(tester, NotificationsDouble());

    expect(find.text('Nothing to report'), findsOneWidget);
  });

  testWidgets('the footer says how much of the whole is held', (
    WidgetTester tester,
  ) async {
    await open(tester, NotificationsDouble(rows: notices(25)));
    await scrollTo(tester, find.text('20 of 25 notifications'));

    expect(find.text('20 of 25 notifications'), findsOneWidget);
  });

  // A page is asked for rather than taken by scrolling, and what is already
  // read stays where it is when the next one arrives.
  testWidgets('asking for more adds the next page to what is read', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      rows: notices(25),
    );
    await open(tester, notifications);

    await scrollTo(tester, find.text('Show more'));
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('25 of 25 notifications'));

    expect(notifications.pagesAsked, <int>[1, 2]);
    expect(find.text('25 of 25 notifications'), findsOneWidget);
  });

  testWidgets('a refused read is said with the trace it can be found by', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NotificationsDouble(
        failure: const ApiException(
          message: 'The API could not be reached.',
          traceId: '00-abc-def-01',
        ),
      ),
    );

    expect(find.text('The API could not be reached.'), findsOneWidget);
    expect(find.text('Trace 00-abc-def-01'), findsOneWidget);
  });

  testWidgets('another go repeats the read that was refused', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(
      failure: const ApiException(message: 'The API could not be reached.'),
    );
    await open(tester, notifications);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(notifications.pagesAsked, <int>[1, 1]);
  });
}
