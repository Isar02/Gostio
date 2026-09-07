import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/app/shell/app_shell.dart';
import 'package:gostio_mobile/features/messages/presentation/conversation_card.dart';

import '../../support/account_fixture.dart';
import '../../support/auth_double.dart';
import '../../support/catalogue_double.dart';
import '../../support/conversation_fixture.dart';
import '../../support/messages_double.dart';
import '../../support/news_double.dart';
import '../../support/notifications_double.dart';
import '../../support/phone.dart';
import '../../support/recommendations_double.dart';
import '../../support/screens.dart';
import '../../support/trips_double.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> openShell(
    WidgetTester tester, {
    ConversationsDouble? conversations,
    MessagesDouble? messages,
  }) async {
    final Session session = signedOutSession()
      ..begin(
        account: account(id: reader),
        token: 'the-token',
      );

    await tester.pumpWidget(
      underTest(
        const AppShell(),
        auth: AuthDouble(),
        session: session,
        news: NewsDouble(),
        notifications: NotificationsDouble(),
        conversations: conversations ?? ConversationsDouble(),
        messages: messages ?? MessagesDouble(),
        catalogue: CatalogueDouble(),
        filterOptions: FilterOptionsDouble(),
        trips: TripsDouble(),
        suggestions: RecommendationsDouble(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openInboxTab(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Inbox'),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The tab is where a reader would go to answer what is waiting, and the bar
  // is on every screen they could be reading instead.
  testWidgets('what is waiting in the inbox is drawn over its tab', (
    WidgetTester tester,
  ) async {
    await openShell(tester, messages: MessagesDouble(unread: 6));

    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('6')),
      findsOneWidget,
    );
  });

  testWidgets('a tab with nothing waiting carries no count', (
    WidgetTester tester,
  ) async {
    await openShell(tester);

    expect(
      find.descendant(of: find.byType(NavigationBar), matching: find.text('0')),
      findsNothing,
    );
  });

  // The threads are the account's own, and which side of one is theirs is what
  // every row on it is drawn against.
  testWidgets('the tab opens on the threads this account is in', (
    WidgetTester tester,
  ) async {
    await openShell(
      tester,
      conversations: ConversationsDouble(rows: <Conversation>[thread()]),
    );
    await openInboxTab(tester);

    expect(find.byType(ConversationCard), findsOneWidget);
    expect(find.text('Lejla Begić'), findsOneWidget);
  });
}
