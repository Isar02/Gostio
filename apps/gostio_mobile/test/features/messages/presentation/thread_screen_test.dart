import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/messages/presentation/thread_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/conversation_fixture.dart';
import '../../../support/messages_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> openThread(
    WidgetTester tester, {
    required MessagesDouble messages,
    Conversation? held,
    ConversationsDouble? conversations,
  }) async {
    final Conversation row = held ?? thread();

    await tester.pumpWidget(
      underTest(
        ThreadScreen(row, callerId: reader),
        auth: AuthDouble(),
        conversations:
            conversations ?? ConversationsDouble(rows: <Conversation>[row]),
        messages: messages,
        chat: ChatHubDouble(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> write(WidgetTester tester, String body) async {
    await tester.enterText(find.byType(TextField), body);
    await tester.pump();
  }

  Future<void> pressSend(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
  }

  testWidgets('the thread is drawn with the newest line last', (
    WidgetTester tester,
  ) async {
    await openThread(
      tester,
      messages: MessagesDouble(
        lines: <Message>[
          line(id: 2, body: 'And the code is on its way.'),
          line(
            id: 1,
            senderUserId: reader,
            senderName: 'Emina Begić',
            body: 'We land around nine.',
            sentAt: DateTime.utc(2026, 9, 5, 9),
          ),
        ],
      ),
    );

    final double newest = tester
        .getCenter(find.text('And the code is on its way.'))
        .dy;
    final double oldest = tester
        .getCenter(find.text('We land around nine.'))
        .dy;

    expect(newest, greaterThan(oldest));
  });

  testWidgets('the thread is named by who it is with and what it is about', (
    WidgetTester tester,
  ) async {
    await openThread(
      tester,
      messages: MessagesDouble(lines: <Message>[line()]),
    );

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Lejla Begić'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Apartment above the Neretva in Konjic'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a thread with nothing in it says so', (
    WidgetTester tester,
  ) async {
    await openThread(tester, messages: MessagesDouble());

    expect(find.text('Nothing said yet'), findsOneWidget);
  });

  testWidgets('a refused read is reported with another go', (
    WidgetTester tester,
  ) async {
    await openThread(
      tester,
      messages: MessagesDouble(
        failure: const ApiException(message: 'The API could not be reached.'),
      ),
    );

    expect(find.text('The API could not be reached.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  // Nothing is written where nothing is waiting: a thread the reader has
  // already seen through does not need to be marked read a second time.
  testWidgets('opening a thread with something waiting marks it read', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: <Message>[line()]);

    await openThread(tester, messages: messages, held: thread(unreadCount: 2));

    expect(messages.markedRead, <int>[7]);
  });

  testWidgets('opening a thread with nothing waiting writes nothing', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: <Message>[line()]);

    await openThread(tester, messages: messages);

    expect(messages.markedRead, isEmpty);
  });

  testWidgets('what was sent joins the thread and the box is emptied', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: <Message>[line()]);

    await openThread(tester, messages: messages);
    await write(tester, 'Nine in the evening suits us.');
    await pressSend(tester);

    expect(messages.bodiesSent, <String>['Nine in the evening suits us.']);
    expect(find.text('Nine in the evening suits us.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
  });

  // The rule the server holds, said before a round trip rather than after one.
  testWidgets('an empty message is refused without being sent', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: <Message>[line()]);

    await openThread(tester, messages: messages);
    await write(tester, '   ');
    await pressSend(tester);

    expect(messages.bodiesSent, isEmpty);
    expect(find.text('A message needs something in it.'), findsOneWidget);
  });

  testWidgets('a local body refusal clears when the body is corrected', (
    WidgetTester tester,
  ) async {
    await openThread(
      tester,
      messages: MessagesDouble(lines: <Message>[line()]),
    );
    await write(tester, '   ');
    await pressSend(tester);

    await write(tester, 'A real question.');

    expect(find.text('A message needs something in it.'), findsNothing);
  });

  testWidgets('a server body refusal clears when the body is corrected', (
    WidgetTester tester,
  ) async {
    await openThread(
      tester,
      messages: MessagesDouble(
        lines: <Message>[line()],
        sendFailure: const ApiException(
          message: 'The message was refused.',
          errors: <String, List<String>>{
            'Body': <String>['Use fewer words.'],
          },
        ),
      ),
    );
    await write(tester, 'A first question.');
    await pressSend(tester);

    await write(tester, 'Shorter.');

    expect(find.text('Use fewer words.'), findsNothing);
  });

  testWidgets('a refused send says so and keeps what was written', (
    WidgetTester tester,
  ) async {
    await openThread(
      tester,
      messages: MessagesDouble(
        lines: <Message>[line()],
        sendFailure: const ApiException(
          message: 'The API could not be reached.',
        ),
      ),
    );
    await write(tester, 'Is the key still in the box?');
    await pressSend(tester);

    expect(find.text('The API could not be reached.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'Is the key still in the box?',
    );
  });

  testWidgets('the send button waits while the line is going', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(
      lines: <Message>[line()],
      holdsTheSend: true,
    );

    await openThread(tester, messages: messages);
    await write(tester, 'On our way.');
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();

    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );

    messages.answerSend();
    await tester.pumpAndSettle();
  });

  testWidgets('a message half written is not discarded without a question', (
    WidgetTester tester,
  ) async {
    final GlobalKey<NavigatorState> navigator = await pushOnto(
      tester,
      ThreadScreen(thread(), callerId: reader),
      auth: AuthDouble(),
      conversations: ConversationsDouble(rows: <Conversation>[thread()]),
      messages: MessagesDouble(lines: <Message>[line()]),
      chat: ChatHubDouble(),
    );

    await write(tester, 'Half of a question');
    navigator.currentState!.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Leave this message?'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(find.byType(ThreadScreen), findsOneWidget);
  });
}
