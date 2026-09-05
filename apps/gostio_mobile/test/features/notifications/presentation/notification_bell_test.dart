import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/shell/app_shell.dart';
import 'package:gostio_mobile/features/notifications/presentation/notifications_screen.dart';

import '../../../support/account_fixture.dart';
import '../../../support/auth_double.dart';
import '../../../support/catalogue_double.dart';
import '../../../support/notice_fixture.dart';
import '../../../support/notifications_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> openShell(
    WidgetTester tester,
    NotificationsDouble notifications,
  ) async {
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await tester.pumpWidget(
      underTest(
        const AppShell(),
        auth: AuthDouble(),
        session: session,
        notifications: notifications,
        catalogue: CatalogueDouble(),
        filterOptions: FilterOptionsDouble(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a bell with nothing behind it carries no badge', (
    WidgetTester tester,
  ) async {
    await openShell(tester, NotificationsDouble());

    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('the bell carries what is unread', (WidgetTester tester) async {
    await openShell(tester, NotificationsDouble(unread: 5));

    expect(find.text('5'), findsOneWidget);
  });

  // One count however many tabs the reader moves through: the tab changes,
  // the number behind the bell does not, and nothing is read a second time.
  testWidgets('every tab draws the same count from the one read', (
    WidgetTester tester,
  ) async {
    final NotificationsDouble notifications = NotificationsDouble(unread: 5);
    await openShell(tester, notifications);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Trips'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
    expect(notifications.countCalls, 1);
  });

  // A panel the width of a phone is a screen with a shadow under it, so the
  // bell opens a screen — inside the tab, which keeps the bar under it.
  testWidgets('the bell opens its screen inside the tab it was tapped in', (
    WidgetTester tester,
  ) async {
    await openShell(
      tester,
      NotificationsDouble(unread: 1, rows: <AppNotification>[notice()]),
    );

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
