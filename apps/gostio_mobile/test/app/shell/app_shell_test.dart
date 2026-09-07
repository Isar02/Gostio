import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/named_trip_screen.dart';
import 'package:gostio_mobile/app/shell/app_shell.dart';
import 'package:gostio_mobile/app/shell/shell_tab.dart';
import 'package:gostio_mobile/app/shell/tab_navigator.dart';
import 'package:gostio_mobile/core/push/push_notice.dart';
import 'package:gostio_mobile/core/widgets/discard_guard.dart';
import 'package:gostio_mobile/features/explore/presentation/explore_screen.dart';
import 'package:gostio_mobile/features/notifications/presentation/notifications_screen.dart';

import '../../support/account_fixture.dart';
import '../../support/auth_double.dart';
import '../../support/catalogue_double.dart';
import '../../support/messages_double.dart';
import '../../support/news_double.dart';
import '../../support/notifications_double.dart';
import '../../support/payment_double.dart';
import '../../support/phone.dart';
import '../../support/push_double.dart';
import '../../support/recommendation_fixture.dart';
import '../../support/recommendations_double.dart';
import '../../support/screens.dart';
import '../../support/trips_double.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> openShell(
    WidgetTester tester, {
    PushMessagingDouble? messaging,
  }) async {
    final Session session = signedOutSession()
      ..begin(account: account(), token: 'the-token');

    await tester.pumpWidget(
      underTest(
        const AppShell(),
        auth: AuthDouble(),
        session: session,
        messaging: messaging,
        news: NewsDouble(),
        notifications: NotificationsDouble(),
        conversations: ConversationsDouble(),
        messages: MessagesDouble(),
        catalogue: CatalogueDouble(),
        filterOptions: FilterOptionsDouble(),
        trips: TripsDouble(),
        // A notice opens a booking inside a tab, and a booking draws what it
        // would cost to settle, so the shell is composed over both.
        payments: PaymentDouble(),
        cardSheet: CardSheetDouble(),
        suggestions: RecommendationsDouble(
          stays: <Recommendation>[pick(title: 'Cottage by the Pliva lakes')],
        ),
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

  // A route that holds something unapplied, pushed the way every screen inside
  // a tab is pushed.
  Future<void> pushGuarded(WidgetTester tester, ShellTab tab) async {
    final NavigatorState navigator = tester.state<NavigatorState>(
      find.descendant(
        of: find.byWidgetPredicate(
          (Widget widget) => widget is TabNavigator && widget.tab == tab,
        ),
        matching: find.byType(Navigator),
      ),
    );

    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const DiscardGuard(
            hasInput: true,
            child: Scaffold(body: Text('A guarded detail')),
          ),
        ),
      ),
    );
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

    expect(find.byType(ExploreScreen), findsOneWidget);
  });

  testWidgets('choosing a tab draws its screen and keeps the bar', (
    WidgetTester tester,
  ) async {
    await openShell(tester);

    await chooseTab(tester, ShellTab.profile);

    expect(find.text('Emina Begić'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  // The suggestions are the tab rather than a screen inside it, so the wiring
  // that draws them is the shell's and is checked here.
  testWidgets('the For you tab draws what the server suggests', (
    WidgetTester tester,
  ) async {
    await openShell(tester);

    await chooseTab(tester, ShellTab.forYou);

    expect(find.text('Cottage by the Pliva lakes'), findsOneWidget);
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
    expect(find.byType(ExploreScreen), findsOneWidget);
  });

  testWidgets('back from another tab returns to the first one', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await chooseTab(tester, ShellTab.inbox);

    await pressBack(tester);

    expect(find.byType(ExploreScreen), findsOneWidget);
  });

  // The only gesture a phone has for a stack several screens deep.
  testWidgets('choosing the tab already open returns it to its own root', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await pushInside(tester, ShellTab.explore);

    await chooseTab(tester, ShellTab.explore);

    expect(find.text('A pushed detail'), findsNothing);
    expect(find.byType(ExploreScreen), findsOneWidget);
  });

  // The shell answers Back for the whole client. If it popped the tab rather
  // than asking it, every guard inside every tab would be answered for.
  testWidgets('back leaves a route holding something unapplied its answer', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await pushGuarded(tester, ShellTab.explore);

    await pressBack(tester);

    expect(find.text('Leave this form?'), findsOneWidget);
    expect(find.text('A guarded detail'), findsOneWidget);

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('A guarded detail'), findsNothing);
    expect(find.byType(ExploreScreen), findsOneWidget);
  });

  // Returning a tab to its root is the other gesture that empties a stack, and
  // it has to leave a route its answer the way Back does.
  testWidgets('returning a tab to its root asks a route holding something', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await pushGuarded(tester, ShellTab.explore);

    await chooseTab(tester, ShellTab.explore);

    expect(find.text('Leave this form?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('A guarded detail'), findsOneWidget);
  });

  // The reader asked for the top of the tab, and one route agreeing to go was
  // not the whole of that. What the question interrupted has to carry on.
  testWidgets('a guard that is answered lets the reset reach the root', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await pushInside(tester, ShellTab.explore);
    await pushGuarded(tester, ShellTab.explore);

    await chooseTab(tester, ShellTab.explore);
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('A guarded detail'), findsNothing);
    expect(find.text('A pushed detail'), findsNothing);
    expect(find.byType(ExploreScreen), findsOneWidget);
  });

  testWidgets('a repeated root request shares the one already in flight', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await pushInside(tester, ShellTab.explore);
    await pushGuarded(tester, ShellTab.explore);

    final NavigationBar bar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    bar.onDestinationSelected!(ShellTab.explore.index);
    bar.onDestinationSelected!(ShellTab.explore.index);
    await tester.pumpAndSettle();

    expect(find.text('Leave this form?'), findsOneWidget);

    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(find.text('A guarded detail'), findsNothing);
    expect(find.text('A pushed detail'), findsNothing);
    expect(find.byType(ExploreScreen), findsOneWidget);
  });

  testWidgets('a guard that is kept leaves the stack under it standing', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await pushInside(tester, ShellTab.explore);
    await pushGuarded(tester, ShellTab.explore);

    await chooseTab(tester, ShellTab.explore);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.text('A guarded detail'), findsOneWidget);

    await pressBack(tester);
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    // Back left the guarded route alone, and nothing carried on emptying the
    // stack behind it: the reset the reader stopped stayed stopped.
    expect(find.text('A pushed detail'), findsOneWidget);
  });

  // Asking one route at a time still has to reach the bottom of the stack.
  testWidgets('returning a tab to its root leaves every screen on it', (
    WidgetTester tester,
  ) async {
    await openShell(tester);
    await pushInside(tester, ShellTab.explore);
    await pushInside(tester, ShellTab.explore);

    await chooseTab(tester, ShellTab.explore);

    expect(find.text('A pushed detail'), findsNothing);
    expect(find.byType(ExploreScreen), findsOneWidget);
  });

  // A delivery the reader tapped opens inside the tab they are in, like every
  // other screen: a push is a way back into the client rather than a place of
  // its own beside it.
  testWidgets('a delivery that was tapped opens the booking it names', (
    WidgetTester tester,
  ) async {
    final PushMessagingDouble messaging = PushMessagingDouble();
    await openShell(tester, messaging: messaging);

    await chooseTab(tester, ShellTab.trips);
    messaging.taps.add(const PushNotice(reservationId: 314));
    await tester.pumpAndSettle();

    expect(find.byType(NamedTripScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await messaging.close();
  });

  // A host verification carries no reservation, and a tap that arrived
  // nowhere would be a gesture that sometimes does nothing.
  testWidgets('a delivery that names no booking opens the notices', (
    WidgetTester tester,
  ) async {
    final PushMessagingDouble messaging = PushMessagingDouble();
    await openShell(tester, messaging: messaging);

    messaging.taps.add(const PushNotice());
    await tester.pumpAndSettle();

    expect(find.byType(NotificationsScreen), findsOneWidget);

    await messaging.close();
  });
}
