import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/notifications/presentation/unread_notices.dart';

import '../../../support/notifications_double.dart';
import '../../../support/phone.dart';

// The count is built inside a widget test because its poll runs on the clock
// the test binding controls, and it is ended inside the test body because the
// binding looks for a pending timer before a tear-down could cancel one.
void main() {
  setUp(usePhoneScreen);

  testWidgets('the count is read as soon as there is somebody to count for', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(unread: 3);
    final UnreadNotices notices = UnreadNotices(notifications);

    await tester.pump();

    expect(notices.unread, 3);
    expect(notifications.countCalls, 1);

    notices.dispose();
  });

  testWidgets('the count is read again on every interval', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(unread: 1);
    final UnreadNotices notices = UnreadNotices(notifications);

    await tester.pump();
    await tester.pump(UnreadNotices.pollInterval);

    expect(notifications.countCalls, 2);

    notices.dispose();
  });

  // A phone in a pocket has no count to draw, and a timer running behind the
  // reader spends battery to learn nothing.
  testWidgets('nothing is polled while the application is in the background', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(unread: 1);
    final UnreadNotices notices = UnreadNotices(notifications);

    await tester.pump();
    notices.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump(UnreadNotices.pollInterval * 3);

    expect(notifications.countCalls, 1);

    notices.dispose();
  });

  // What arrived while the application was away is the reason it was opened,
  // so coming back asks at once rather than waiting out the interval.
  testWidgets('coming back to the foreground asks straight away', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(unread: 1);
    final UnreadNotices notices = UnreadNotices(notifications);

    await tester.pump();
    notices
      ..didChangeAppLifecycleState(AppLifecycleState.paused)
      ..didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();

    expect(notifications.countCalls, 2);

    notices.dispose();
  });

  // The bell is not the surface a network fault is worth reporting on. The
  // count stands until a read succeeds.
  testWidgets('a refused read leaves the count as it was', (
    WidgetTester tester,
  ) async {
    final UnreadNotices notices = UnreadNotices(
      NotificationsDouble(
        unread: 4,
        failure: const ApiException(message: 'The API could not be reached.'),
      ),
    );

    await tester.pump();

    expect(notices.unread, 0);

    notices.dispose();
  });
}
