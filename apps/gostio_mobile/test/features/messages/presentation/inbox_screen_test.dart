import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/messages/presentation/inbox_screen.dart';
import 'package:gostio_mobile/features/messages/presentation/thread_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/conversation_fixture.dart';
import '../../../support/messages_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> openInbox(
    WidgetTester tester, {
    required ConversationsDouble conversations,
    MessagesDouble? messages,
    ChatHubDouble? chat,
  }) async {
    await tester.pumpWidget(
      underTest(
        const Scaffold(body: InboxScreen(callerId: reader)),
        auth: AuthDouble(),
        conversations: conversations,
        messages: messages ?? MessagesDouble(),
        chat: chat ?? ChatHubDouble(),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The inbox is not in the thread's group, so the nudge is what reaches it.
  testWidgets('a nudge from the hub brings the newest page in', (
    WidgetTester tester,
  ) async {
    final ConversationsDouble conversations = ConversationsDouble(
      rows: <Conversation>[thread()],
    );
    final ChatHubDouble hub = ChatHubDouble();

    await openInbox(tester, conversations: conversations, chat: hub);

    final int readSoFar = conversations.pagesAsked.length;

    conversations.rows.insert(
      0,
      thread(id: 42, listingTitle: 'Riverside flat in Tuzla'),
    );
    await hub.touch(42);
    await tester.pumpAndSettle();

    expect(conversations.pagesAsked.length, greaterThan(readSoFar));
    expect(find.textContaining('Riverside flat in Tuzla'), findsOneWidget);
  });

  testWidgets('a row says who the thread is with, what it is about and the '
      'last thing said in it', (WidgetTester tester) async {
    await openInbox(
      tester,
      conversations: ConversationsDouble(
        rows: <Conversation>[
          thread(lastMessage: line(body: 'There is room for two cars inside.')),
        ],
      ),
    );

    expect(find.text('Lejla Begić'), findsOneWidget);
    expect(find.text('Apartment above the Neretva in Konjic'), findsOneWidget);
    expect(find.text('There is room for two cars inside.'), findsOneWidget);
    expect(find.text('1 of 1 conversations'), findsOneWidget);
  });

  // Which side said it matters more than the words on a row that only has room
  // for one line of them.
  testWidgets('a line the reader sent is named as theirs', (
    WidgetTester tester,
  ) async {
    await openInbox(
      tester,
      conversations: ConversationsDouble(
        rows: <Conversation>[
          thread(
            lastMessage: line(
              senderUserId: reader,
              body: 'That works, thanks.',
            ),
          ),
        ],
      ),
    );

    expect(find.text('You: That works, thanks.'), findsOneWidget);
  });

  testWidgets('what is waiting in a thread is counted on its row', (
    WidgetTester tester,
  ) async {
    await openInbox(
      tester,
      conversations: ConversationsDouble(
        rows: <Conversation>[thread(unreadCount: 3)],
      ),
    );

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('a thread with nothing waiting carries no count', (
    WidgetTester tester,
  ) async {
    await openInbox(
      tester,
      conversations: ConversationsDouble(rows: <Conversation>[thread()]),
    );

    expect(find.text('0'), findsNothing);
  });

  // A support thread has nobody else in it until somebody answers it, and it
  // still has a name before then.
  testWidgets('a support thread is named without a second party', (
    WidgetTester tester,
  ) async {
    await openInbox(
      tester,
      conversations: ConversationsDouble(
        rows: <Conversation>[
          thread(
            type: ConversationType.support,
            reservationId: null,
            listingTitle: null,
            participants: <ConversationParticipant>[party()],
            lastMessage: line(
              senderUserId: reader,
              senderName: 'Emina Begić',
              body: 'My refund has not arrived yet.',
            ),
          ),
        ],
      ),
    );

    expect(find.text('Gostio support'), findsOneWidget);
    expect(find.text('Help with your account'), findsOneWidget);
  });

  // Support is one entry rather than a thread the reader has to find: above
  // the list where there is one, and inside the empty state where there is not.
  testWidgets('support is offered whether or not there are threads', (
    WidgetTester tester,
  ) async {
    await openInbox(
      tester,
      conversations: ConversationsDouble(rows: <Conversation>[thread()]),
    );

    expect(find.text('Ask Gostio support'), findsOneWidget);

    await openInbox(tester, conversations: ConversationsDouble());

    expect(find.text('Ask Gostio support'), findsOneWidget);
  });

  testWidgets('an inbox with nothing in it says what opens there', (
    WidgetTester tester,
  ) async {
    await openInbox(tester, conversations: ConversationsDouble());

    expect(find.text('No messages yet'), findsOneWidget);
  });

  testWidgets('a refused read is reported with another go', (
    WidgetTester tester,
  ) async {
    await openInbox(
      tester,
      conversations: ConversationsDouble(
        failure: const ApiException(
          message: 'The API could not be reached.',
          traceId: 'trace-88',
        ),
      ),
    );

    expect(find.text('The API could not be reached.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('a row opens the thread it stands for', (
    WidgetTester tester,
  ) async {
    await openInbox(
      tester,
      conversations: ConversationsDouble(rows: <Conversation>[thread()]),
      messages: MessagesDouble(lines: <Message>[line()]),
    );

    await tester.tap(find.text('Lejla Begić'));
    await tester.pumpAndSettle();

    expect(find.byType(ThreadScreen), findsOneWidget);
  });

  // The list read the row before the reader was in the thread. Reading the
  // whole list again to show one changed row would take a list several pages
  // deep back to its first page.
  testWidgets('a thread read on its own screen comes back to its row', (
    WidgetTester tester,
  ) async {
    final ConversationsDouble conversations = ConversationsDouble(
      rows: <Conversation>[thread(unreadCount: 4)],
    )..readsBack = thread(lastMessage: line(body: 'Seen it all now.'));

    await openInbox(
      tester,
      conversations: conversations,
      messages: MessagesDouble(lines: <Message>[line()]),
    );

    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('Lejla Begić'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('4'), findsNothing);
    expect(find.text('Seen it all now.'), findsOneWidget);
    expect(conversations.pagesAsked, <int>[1]);
  });

  // The server keeps this list in the order it was last spoken in, and a
  // thread the reader has just answered is the one row that can have left it.
  testWidgets('a thread just spoken in is drawn first', (
    WidgetTester tester,
  ) async {
    final ConversationsDouble conversations =
        ConversationsDouble(
            rows: <Conversation>[
              thread(
                id: 1,
                listingTitle: 'Seafront apartment in Neum',
                lastActivityAt: DateTime.utc(2026, 9, 6, 12),
              ),
              thread(
                id: 2,
                listingTitle: 'Riverside flat in Tuzla',
                lastActivityAt: DateTime.utc(2026, 9, 4, 12),
              ),
            ],
          )
          ..readsBack = thread(
            id: 2,
            listingTitle: 'Riverside flat in Tuzla',
            lastActivityAt: DateTime.utc(2026, 9, 7, 12),
          );

    await openInbox(
      tester,
      conversations: conversations,
      messages: MessagesDouble(lines: <Message>[line()]),
    );

    expect(
      tester.getCenter(find.text('Riverside flat in Tuzla')).dy,
      greaterThan(tester.getCenter(find.text('Seafront apartment in Neum')).dy),
    );

    await tester.tap(find.text('Riverside flat in Tuzla'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'On our way.');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(
      tester.getCenter(find.text('Riverside flat in Tuzla')).dy,
      lessThan(tester.getCenter(find.text('Seafront apartment in Neum')).dy),
    );
  });
}
