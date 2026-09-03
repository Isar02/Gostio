import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/widgets/account_avatar.dart';
import 'package:gostio_desktop/features/messages/data/chat_hub.dart';
import 'package:gostio_desktop/features/messages/data/conversation.dart';
import 'package:gostio_desktop/features/messages/data/conversation_participant.dart';
import 'package:gostio_desktop/features/messages/data/conversation_type.dart';
import 'package:gostio_desktop/features/messages/data/conversations_repository.dart';
import 'package:gostio_desktop/features/messages/data/message.dart';
import 'package:gostio_desktop/features/messages/data/messages_repository.dart';
import 'package:gostio_desktop/features/messages/presentation/chat_unread_notifier.dart';
import 'package:gostio_desktop/features/messages/presentation/message_bubble.dart';
import 'package:gostio_desktop/features/messages/presentation/messages_screen.dart';
import 'package:gostio_desktop/features/messages/presentation/thread_notifier.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/chat_doubles.dart';
import '../../../support/conversation_doubles.dart';
import '../../../support/conversation_fixture.dart';

// The window this client is drawn for. A split view is the one screen whose
// two halves both need it, so the tests measure it rather than the default.
const Size _window = Size(1440, 900);

void main() {
  setUp(() {
    final TestFlutterView view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .implicitView!;

    view.physicalSize = _window;
    view.devicePixelRatio = 1;

    addTearDown(view.reset);
  });

  testWidgets('a thread is drawn by who it is with, its kind and what was '
      'said last', (WidgetTester tester) async {
    await tester.pumpWidget(_screen(threads: _oneThread()));
    await tester.pumpAndSettle();

    expect(find.text('Maja Popović'), findsOneWidget);
    expect(find.text('Support'), findsOneWidget);
    expect(
      find.textContaining('My refund is showing as processed'),
      findsOneWidget,
    );
    expect(find.text('1'), findsOneWidget);

    await _leave(tester);
  });

  testWidgets('nothing chosen says where to choose it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(threads: _oneThread()));
    await tester.pumpAndSettle();

    expect(find.text('No thread open'), findsOneWidget);

    await _leave(tester);
  });

  testWidgets('an inbox with nothing in it names the side these are opened '
      'from', (WidgetTester tester) async {
    await tester.pumpWidget(_screen(threads: ConversationsDouble()));
    await tester.pumpAndSettle();

    expect(find.text('No threads'), findsOneWidget);

    await _leave(tester);
  });

  testWidgets('an inbox that could not be read says what the API said, with '
      'its trace', (WidgetTester tester) async {
    await tester.pumpWidget(
      _screen(threads: ConversationsDouble(failing: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('The threads could not be read.'), findsOneWidget);
    expect(find.text('Trace c3d9f1'), findsOneWidget);

    await _leave(tester);
  });

  testWidgets('choosing a thread reads it, marks it read and draws what was '
      'said', (WidgetTester tester) async {
    final MessagesDouble messages = _messages();
    await tester.pumpWidget(_screen(threads: _oneThread(), messages: messages));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maja Popović').first);
    await tester.pumpAndSettle();

    expect(find.text('A request written to support'), findsOneWidget);
    expect(find.text('It left us on Tuesday.'), findsOneWidget);
    expect(messages.markedRead, 1);

    await _leave(tester);
  });

  // A picture stands beside a name here the way it does beside a row, and the
  // reader's own words need no face against them.
  testWidgets('the other side is drawn beside what they said', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(threads: _oneThread(), messages: _messages()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maja Popović').first);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(MessageBubble),
        matching: find.byType(AccountAvatar),
      ),
      findsOneWidget,
    );

    await _leave(tester);
  });

  testWidgets('an answer is written, sent and the box left empty', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = _messages();
    await tester.pumpWidget(_screen(threads: _oneThread(), messages: messages));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maja Popović').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'Write again on Friday if it has not arrived.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(messages.written, <String>[
      'Write again on Friday if it has not arrived.',
    ]);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      isEmpty,
    );

    await _leave(tester);
  });

  // Nothing is written from this side without words in it, and the refusal is
  // the server's own sentence said before the call is made.
  testWidgets('an empty answer is refused under the box', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = _messages();
    await tester.pumpWidget(_screen(threads: _oneThread(), messages: messages));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maja Popović').first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Send'));
    await tester.pumpAndSettle();

    expect(find.text('A message needs something in it.'), findsOneWidget);
    expect(messages.written, isEmpty);

    await _leave(tester);
  });

  // An administrator reaches a support thread before answering it, and the
  // answer is what puts them in it.
  testWidgets('a thread nobody has answered says that sending joins it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        threads: ConversationsDouble(
          rows: <Conversation>[
            conversation(
              participants: <ConversationParticipant>[participant()],
            ),
          ],
        ),
        messages: _messages(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maja Popović').first);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Sending puts this account in the thread;'),
      findsOneWidget,
    );

    await _leave(tester);
  });

  testWidgets('the kind narrows the inbox', (WidgetTester tester) async {
    final ConversationsDouble threads = _oneThread();
    await tester.pumpWidget(_screen(threads: threads));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Any'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Direct').last);
    await tester.pumpAndSettle();

    expect(threads.queries.last.type, ConversationType.direct);

    await _leave(tester);
  });

  // The hub is the only thing that makes a thread live, and a thread it never
  // answers for reads itself again rather than sitting there.
  testWidgets('a thread the hub has not answered for reads itself again', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = _messages();
    await tester.pumpWidget(_screen(threads: _oneThread(), messages: messages));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maja Popović').first);
    await tester.pumpAndSettle();

    expect(find.text('Refreshing'), findsOneWidget);
    expect(messages.pagesRead, <int>[1]);

    await tester.pump(ThreadNotifier.refreshInterval);
    await tester.pumpAndSettle();

    expect(messages.pagesRead, <int>[1, 1]);

    await _leave(tester);
  });

  testWidgets('a thread the hub is carrying says so and stops asking', (
    WidgetTester tester,
  ) async {
    final ChatHubDouble hub = ChatHubDouble();
    final MessagesDouble messages = _messages();
    await tester.pumpWidget(
      _screen(threads: _oneThread(), messages: messages, hub: hub),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Maja Popović').first);
    await tester.pumpAndSettle();

    await hub.say(7, const ChatJoined());
    await tester.pumpAndSettle();

    expect(find.text('Live'), findsOneWidget);

    await tester.pump(ThreadNotifier.refreshInterval);
    await tester.pumpAndSettle();

    expect(messages.pagesRead, <int>[1]);

    await _leave(tester);
  });
}

ConversationsDouble _oneThread() =>
    ConversationsDouble(rows: <Conversation>[conversation()]);

MessagesDouble _messages() => MessagesDouble(
  pagesOfLines: <List<Message>>[
    <Message>[
      message(
        id: 2,
        senderUserId: administratorId,
        senderName: 'Dina Kovačević',
        body: 'It left us on Tuesday.',
        sentAt: DateTime.utc(2026, 8, 28, 9, 7),
      ),
      message(id: 1, sentAt: DateTime.utc(2026, 8, 28, 9)),
    ],
  ],
);

Widget _screen({
  required ConversationsDouble threads,
  MessagesDouble? messages,
  ChatHubDouble? hub,
}) {
  final MessagesDouble reading = messages ?? MessagesDouble();

  return MultiProvider(
    providers: <SingleChildWidget>[
      Provider<ConversationsRepository>.value(value: threads),
      Provider<MessagesRepository>.value(value: reading),
      Provider<ChatHub>.value(value: hub ?? ChatHubDouble()),
      ChangeNotifierProvider<ChatUnreadNotifier>(
        create: (BuildContext context) => ChatUnreadNotifier(reading),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: MessagesScreen(
          signedInUserId: administratorId,
          onlyThreadsJoined: false,
        ),
      ),
    ),
  );
}

// The screen is left, which is what stops the inbox and the thread reading
// themselves again. A test that stayed on it would end with both still going.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}
