import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/messages/presentation/thread_notifier.dart';

import '../../../support/conversation_fixture.dart';
import '../../../support/messages_double.dart';

void main() {
  ThreadNotifier open(
    MessagesDouble messages, {
    ConversationsDouble? conversations,
    Conversation? held,
    void Function(Conversation thread)? onThreadChanged,
    void Function(int unread)? onUnread,
  }) {
    final Conversation row = held ?? thread();

    return ThreadNotifier(
      messages,
      conversations ?? ConversationsDouble(rows: <Conversation>[row]),
      row,
      callerId: reader,
      onThreadChanged: onThreadChanged,
      onUnread: onUnread,
    );
  }

  List<Message> saidOver(int count) => <Message>[
    for (int index = count; index >= 1; index--)
      line(
        id: index,
        body: 'Line $index',
        sentAt: DateTime.utc(2026, 9, 5, 9).add(Duration(minutes: index)),
      ),
  ];

  test('a thread opens on its first page, newest first', () async {
    final ThreadNotifier thread = open(MessagesDouble(lines: saidOver(41)));

    await thread.open();

    expect(thread.lines.length, 20);
    expect(thread.lines.first.body, 'Line 41');
    expect(thread.hasEarlier, isTrue);
  });

  // Earlier lines are a page further back rather than a page instead of this
  // one, so the whole thread stays on the screen once it has been read.
  test('earlier lines are added to what is already held', () async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(41));
    final ThreadNotifier thread = open(messages);

    await thread.open();
    await thread.readEarlier();

    expect(messages.pagesAsked, <int>[1, 2]);
    expect(thread.lines.length, 40);
    expect(thread.lines.first.body, 'Line 41');
    expect(thread.lines.last.body, 'Line 2');
  });

  test('nothing is asked for past the end of the thread', () async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(3));
    final ThreadNotifier thread = open(messages);

    await thread.open();
    await thread.readEarlier();

    expect(messages.pagesAsked, <int>[1]);
    expect(thread.hasEarlier, isFalse);
  });

  // A line sent is held by the answer to the send and could be read again by
  // the next page, and it is one line either way.
  test('a line already held is not held a second time', () async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(3));
    final ThreadNotifier thread = open(messages);

    await thread.open();
    await thread.open();

    expect(thread.lines.length, 3);
  });

  test('what was sent joins the thread as its newest line', () async {
    final ThreadNotifier thread = open(MessagesDouble(lines: saidOver(3)));

    await thread.open();
    final bool sent = await thread.send('On our way.');

    expect(sent, isTrue);
    expect(thread.lines.first.body, 'On our way.');
    expect(thread.lines.length, 4);
  });

  test('a refused send leaves the thread as it was and says why', () async {
    final ThreadNotifier thread = open(
      MessagesDouble(
        lines: saidOver(3),
        sendFailure: const ApiException(
          message: 'The API could not be reached.',
        ),
      ),
    );

    await thread.open();
    final bool sent = await thread.send('On our way.');

    expect(sent, isFalse);
    expect(thread.lines.length, 3);
    expect(thread.sendFailureMessage, 'The API could not be reached.');
  });

  // The row the list this thread was opened from is showing was read before
  // the reader was in it, so what the server holds afterwards goes back to it.
  test('the row read back after a write goes to whoever holds it', () async {
    final ConversationsDouble conversations = ConversationsDouble()
      ..readsBack = thread(unreadCount: 0);
    final List<Conversation> reported = <Conversation>[];
    final List<int> counted = <int>[];

    final ThreadNotifier opened = open(
      MessagesDouble(lines: saidOver(2)),
      conversations: conversations,
      held: thread(unreadCount: 2),
      onThreadChanged: reported.add,
      onUnread: counted.add,
    );

    await opened.open();

    expect(counted, <int>[0]);
    expect(reported.single.unreadCount, 0);
    expect(opened.thread.unreadCount, 0);
  });

  test('a thread with nothing waiting is not marked read', () async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(2));

    await open(messages).open();

    expect(messages.markedRead, isEmpty);
  });

  test('a refused first read is reported and holds no lines', () async {
    final ThreadNotifier thread = open(
      MessagesDouble(
        failure: const ApiException(
          message: 'The API could not be reached.',
          traceId: 'trace-12',
        ),
      ),
    );

    await thread.open();

    expect(thread.lines, isEmpty);
    expect(thread.failureMessage, 'The API could not be reached.');
    expect(thread.failureTraceId, 'trace-12');
  });
}
