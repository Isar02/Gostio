import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/messages/data/chat_hub.dart';
import 'package:gostio_desktop/features/messages/data/message.dart';
import 'package:gostio_desktop/features/messages/presentation/thread_notifier.dart';

import '../../../support/chat_doubles.dart';
import '../../../support/conversation_doubles.dart';
import '../../../support/conversation_fixture.dart';

void main() {
  // The API answers a thread newest first, and a thread is read oldest first.
  test('a thread is drawn in the order it was said', () async {
    final ThreadNotifier lines = _thread(
      MessagesDouble(pagesOfLines: <List<Message>>[_newestFirst]),
    );

    await lines.open();

    expect(lines.lines.map((Message said) => said.id), <int>[1, 2, 3]);
    expect(lines.hasEarlier, isFalse);
  });

  // The marking answers with what is unread everywhere, which is the number
  // the badge over the navigation is holding.
  test('opening a thread marks it read and corrects the badge', () async {
    final MessagesDouble messages = MessagesDouble(
      pagesOfLines: <List<Message>>[_newestFirst],
      unread: 4,
    );

    final List<int> counted = <int>[];
    final ThreadNotifier lines = _thread(messages, onRead: counted.add);

    await lines.open();

    expect(messages.markedRead, 1);
    expect(counted, <int>[4]);
  });

  test('what the hub says lands in the thread and is marked read', () async {
    final MessagesDouble messages = MessagesDouble(
      pagesOfLines: <List<Message>>[_newestFirst],
    );
    final ChatHubDouble hub = ChatHubDouble();
    final ThreadNotifier lines = _thread(messages, hub: hub);

    await lines.open();
    await hub.say(7, const ChatJoined());
    await hub.say(
      7,
      ChatSaid(message(id: 4, sentAt: DateTime.utc(2026, 8, 28, 9, 20))),
    );

    expect(lines.isLive, isTrue);
    expect(lines.lines.last.id, 4);
    expect(messages.markedRead, 2);
  });

  // The sender is in the group the broadcast goes to, so a message written
  // here comes back through the hub as well as through the answer.
  test('a message the hub repeats back is held once', () async {
    final MessagesDouble messages = MessagesDouble(
      pagesOfLines: <List<Message>>[_newestFirst],
    );
    final ChatHubDouble hub = ChatHubDouble();
    final ThreadNotifier lines = _thread(messages, hub: hub);

    await lines.open();

    expect(await lines.send('It left us on Tuesday.'), isTrue);

    final Message written = lines.lines.last;
    await hub.say(7, ChatSaid(written));

    expect(messages.written, <String>['It left us on Tuesday.']);
    expect(
      lines.lines.where((Message said) => said.id == written.id),
      hasLength(1),
    );
    expect(lines.lines, hasLength(4));
  });

  // Answering is reading, and on a support thread it is also what puts the
  // account in it, so both the row and the badge are asked for again.
  test('an answer marks the thread read', () async {
    final MessagesDouble messages = MessagesDouble(
      pagesOfLines: <List<Message>>[_newestFirst],
      unread: 2,
    );

    final List<int> counted = <int>[];
    final ThreadNotifier lines = _thread(messages, onRead: counted.add);

    await lines.open();
    await lines.send('Write again on Friday.');

    expect(messages.markedRead, 2);
    expect(counted, <int>[2, 2]);
  });

  // The words are still in the box, so the refusal is said above it rather
  // than thrown at the thread.
  test('a refused message is said and nothing is added', () async {
    final MessagesDouble messages = MessagesDouble(
      pagesOfLines: <List<Message>>[_newestFirst],
      refusing: const ApiException(
        message: 'A message is at most 2000 characters long.',
        statusCode: 400,
      ),
    );
    final ThreadNotifier lines = _thread(messages);

    await lines.open();

    expect(await lines.send('Too much.'), isFalse);
    expect(
      lines.sendFailureMessage,
      'A message is at most 2000 characters long.',
    );
    expect(lines.lines, hasLength(3));
    expect(lines.isSending, isFalse);
    expect(lines.failureMessage, isNull);
  });

  // A refusal that names the field is drawn under the box, so the thread does
  // not say it a second time above.
  test('a refusal that names the field is left to the box', () async {
    final MessagesDouble messages = MessagesDouble(
      pagesOfLines: <List<Message>>[_newestFirst],
      refusing: const ApiException(
        message: 'The message could not be sent.',
        statusCode: 400,
        errors: <String, List<String>>{
          'Body': <String>['A message needs something in it.'],
        },
      ),
    );
    final ThreadNotifier lines = _thread(messages);

    await lines.open();
    await lines.send('  ');

    expect(lines.sendFailureMessage, isNull);
    expect(lines.messageFor('body'), 'A message needs something in it.');
  });

  test('the page before is read onto the front of the thread', () async {
    final MessagesDouble messages = MessagesDouble(
      pagesOfLines: <List<Message>>[_newestFirst, _older],
      totalCount: 5,
    );
    final ThreadNotifier lines = _thread(messages);

    await lines.open();

    expect(lines.hasEarlier, isTrue);

    await lines.readEarlier();

    expect(lines.lines.map((Message said) => said.id), <int>[-2, -1, 1, 2, 3]);
    expect(lines.hasEarlier, isFalse);
    expect(messages.pagesRead, <int>[1, 2]);
  });

  test('a thread that could not be read says so with its trace', () async {
    final ThreadNotifier lines = _thread(MessagesDouble(failing: true));

    await lines.open();

    expect(lines.failureMessage, 'The thread could not be read.');
    expect(lines.failureTraceId, '7f2a10');
    expect(lines.isLoading, isFalse);
    expect(lines.lines, isEmpty);
  });

  // Being carried by the hub and reading itself again are the two ways a
  // thread keeps up, and it is never in both at once.
  test('a thread the hub drops is not live', () async {
    final ChatHubDouble hub = ChatHubDouble();
    final ThreadNotifier lines = _thread(
      MessagesDouble(pagesOfLines: <List<Message>>[_newestFirst]),
      hub: hub,
    );

    await lines.open();
    await hub.say(7, const ChatJoined());

    expect(lines.isLive, isTrue);

    await hub.say(7, const ChatDropped('The socket closed.'));

    expect(lines.isLive, isFalse);
    expect(lines.liveFailureMessage, 'The socket closed.');

    await hub.say(7, const ChatJoined());

    expect(lines.liveFailureMessage, isNull);
  });

  test('leaving a thread gives up its place at the hub', () async {
    final ChatHubDouble hub = ChatHubDouble();
    final ThreadNotifier lines = ThreadNotifier(
      MessagesDouble(pagesOfLines: <List<Message>>[_newestFirst]),
      hub,
      conversationId: 7,
      callerId: administratorId,
    );

    await lines.open();

    expect(hub.watched, <int>[7]);

    lines.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(hub.given, <int>[7]);
  });
}

// The page as the API answers it: newest first.
final List<Message> _newestFirst = <Message>[
  message(id: 3, sentAt: DateTime.utc(2026, 8, 28, 9, 14)),
  message(
    id: 2,
    senderUserId: administratorId,
    senderName: 'Dina Kovačević',
    sentAt: DateTime.utc(2026, 8, 28, 9, 7),
  ),
  message(id: 1, sentAt: DateTime.utc(2026, 8, 28, 9)),
];

final List<Message> _older = <Message>[
  message(id: -1, sentAt: DateTime.utc(2026, 8, 27, 18)),
  message(id: -2, sentAt: DateTime.utc(2026, 8, 27, 17)),
];

ThreadNotifier _thread(
  MessagesDouble messages, {
  ChatHubDouble? hub,
  void Function(int unread)? onRead,
}) {
  final ChatHubDouble reaching = hub ?? ChatHubDouble();
  final ThreadNotifier lines = ThreadNotifier(
    messages,
    reaching,
    conversationId: 7,
    callerId: administratorId,
    onRead: onRead,
  );

  addTearDown(() async {
    lines.dispose();
    await reaching.close();
  });

  return lines;
}
