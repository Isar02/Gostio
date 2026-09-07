import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/messages/data/thread_subject.dart';
import 'package:gostio_mobile/features/messages/presentation/open_thread_button.dart';
import 'package:gostio_mobile/features/messages/presentation/thread_screen.dart';

import '../../../support/account_fixture.dart';
import '../../../support/auth_double.dart';
import '../../../support/conversation_fixture.dart';
import '../../../support/messages_double.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> drawButton(
    WidgetTester tester,
    ThreadSubject subject, {
    required ConversationsDouble conversations,
  }) async {
    final Session session = signedOutSession()
      ..begin(
        account: account(id: reader),
        token: 'the-token',
      );

    await tester.pumpWidget(
      underTest(
        Scaffold(
          body: OpenThreadButton(subject: subject, label: 'Message the host'),
        ),
        auth: AuthDouble(),
        session: session,
        conversations: conversations,
        messages: MessagesDouble(lines: <Message>[line()]),
        chat: ChatHubDouble(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the thread is opened about what the button names', (
    WidgetTester tester,
  ) async {
    final ConversationsDouble conversations = ConversationsDouble();

    await drawButton(
      tester,
      const WithHost(host),
      conversations: conversations,
    );
    await tester.tap(find.text('Message the host'));
    await tester.pumpAndSettle();

    expect(conversations.opened.single, isA<WithHost>());
    expect(find.byType(ThreadScreen), findsOneWidget);
  });

  testWidgets('a thread about a booking names the booking', (
    WidgetTester tester,
  ) async {
    final ConversationsDouble conversations = ConversationsDouble();

    await drawButton(
      tester,
      const AboutBooking(314),
      conversations: conversations,
    );
    await tester.tap(find.text('Message the host'));
    await tester.pumpAndSettle();

    expect((conversations.opened.single as AboutBooking).reservationId, 314);
  });

  testWidgets('support is a route of its own', (WidgetTester tester) async {
    final ConversationsDouble conversations = ConversationsDouble();

    await drawButton(tester, const WithSupport(), conversations: conversations);
    await tester.tap(find.text('Message the host'));
    await tester.pumpAndSettle();

    expect(conversations.opened.single, isA<WithSupport>());
    expect(find.text('Gostio support'), findsWidgets);
  });

  testWidgets('a refusal is reported and no thread is opened', (
    WidgetTester tester,
  ) async {
    final ConversationsDouble conversations = ConversationsDouble()
      ..refusesToOpen = const ApiException(
        message: 'An enquiry is written to an account that hosts.',
      );

    await drawButton(
      tester,
      const WithHost(host),
      conversations: conversations,
    );
    await tester.tap(find.text('Message the host'));
    await tester.pumpAndSettle();

    expect(find.byType(ThreadScreen), findsNothing);
    expect(
      find.text('An enquiry is written to an account that hosts.'),
      findsOneWidget,
    );
  });
}
