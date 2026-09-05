import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/shell/app_shell.dart';
import 'package:gostio_mobile/app/shell/shell_tab.dart';
import 'package:gostio_mobile/app/shell/tab_navigator.dart';

import '../../support/account_fixture.dart';
import '../../support/auth_double.dart';
import '../../support/notifications_double.dart';
import '../../support/phone.dart';
import '../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> openShell(WidgetTester tester) async {
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await tester.pumpWidget(
      underTest(
        const AppShell(),
        auth: AuthDouble(),
        session: session,
        notifications: NotificationsDouble(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // A tab is chosen by its label in the bar, which is the only thing on the
  // screen that carries all five of them.
  Future<void> chooseTab(WidgetTester tester, ShellTab tab) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(tab.label),
      ),
    );
    await tester.pumpAndSettle();
  }

  // A detail is opened the way a screen inside a tab opens one: through the
  // navigator of the tab it belongs to, never over the shell.
  Future<void> pushInside(WidgetTester tester, ShellTab tab) async {
    final NavigatorState navigator = tester.state<NavigatorState>(
      find.descendant(
        of: find.byWidgetPredicate(
          (Widget widget) => widget is TabNavigator && widget.tab == tab,
        ),
        matching: find.byType(Navigator),
      ),
    );

    // The push is not awaited: a route's own future answers when it is popped,
    // which is after the test has finished with it.
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              const Scaffold(body: Text('A pushed detail')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('the client opens on the first tab with all five reachable', (
    WidgetTester tester,
  ) async {
    await openShell(tester);

    for (final ShellTab tab in ShellTab.values) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(tab.label),
        ),
        findsOneWidget,
      );
    }

    expect(find.text('Stays and experiences'), findsOneWidget);
  });

  testWidgets('choosing a tab draws its screen and keeps the bar', (
    WidgetTester tester,
  ) async {
    await openShell(tester);

    await chooseTab(tester, ShellTab.profile);

    expect(find.text('Emina Begić'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  // The bar is the point of a shell. A screen that covered it would be a
  // screen the reader has to leave before they can go anywhere else.
  testWidgets('a screen pushed inside a tab is drawn over the tab alone', (
    WidgetTester tester,
  ) async {
    await openShell(tester);

    await pushInside(tester, ShellTab.explore);

    expect(find.text('A pushed detail'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('a tab keeps what was pushed on it while another is read', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await pushInside(tester, ShellTab.explore);

    await chooseTab(tester, ShellTab.trips);
    await chooseTab(tester, ShellTab.explore);

    expect(find.text('A pushed detail'), findsOneWidget);
  });

  testWidgets('back leaves the pushed screen rather than the tab', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await pushInside(tester, ShellTab.explore);

    await pressBack(tester);

    expect(find.text('A pushed detail'), findsNothing);
    expect(find.text('Stays and experiences'), findsOneWidget);
  });

  testWidgets('back from another tab returns to the first one', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await chooseTab(tester, ShellTab.inbox);

    await pressBack(tester);

    expect(find.text('Stays and experiences'), findsOneWidget);
  });

  // The only gesture a phone has for a stack several screens deep.
  testWidgets('choosing the tab already open returns it to its own root', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await pushInside(tester, ShellTab.explore);

    await chooseTab(tester, ShellTab.explore);

    expect(find.text('A pushed detail'), findsNothing);
    expect(find.text('Stays and experiences'), findsOneWidget);
  });
}
