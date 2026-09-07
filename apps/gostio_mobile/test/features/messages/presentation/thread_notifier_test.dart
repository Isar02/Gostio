import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/messages/data/chat_hub.dart';
import 'package:gostio_mobile/features/messages/presentation/thread_liveness.dart';
import 'package:gostio_mobile/features/messages/presentation/thread_notifier.dart';

import '../../../support/conversation_fixture.dart';
import '../../../support/messages_double.dart';

// These are widget tests because the thread holds a socket and a timer: both
// run on the clock the test binding controls, and both are ended inside the
// test body, because the binding looks for a pending timer before a tear-down
// could cancel one.
void main() {
  ThreadNotifier open(
    MessagesDouble messages, {
    ConversationsDouble? conversations,
    ChatHubDouble? hub,
    Conversation? held,
    void Function(Conversation thread)? onThreadChanged,
    Future<void> Function(Future<int> unread)? onUnread,
  }) {
    final Conversation row = held ?? thread();

    return ThreadNotifier(
      messages,
      conversations ?? ConversationsDouble(rows: <Conversation>[row]),
      hub ?? ChatHubDouble(),
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

  testWidgets('a thread opens on its first page, newest first', (
    WidgetTester tester,
  ) async {
    final ThreadNotifier thread = open(MessagesDouble(lines: saidOver(41)));

    await thread.open();

    expect(thread.lines.length, 20);
    expect(thread.lines.first.body, 'Line 41');
    expect(thread.hasEarlier, isTrue);

    thread.dispose();
  });

  // Earlier lines are a page further back rather than a page instead of this
  // one, so the whole thread stays on the screen once it has been read.
  testWidgets('earlier lines are added to what is already held', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(41));
    final ThreadNotifier thread = open(messages);

    await thread.open();
    await thread.readEarlier();

    expect(messages.pagesAsked, <int>[1, 2]);
    expect(thread.lines.length, 40);
    expect(thread.lines.first.body, 'Line 41');
    expect(thread.lines.last.body, 'Line 2');

    thread.dispose();
  });

  testWidgets('nothing is asked for past the end of the thread', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(3));
    final ThreadNotifier thread = open(messages);

    await thread.open();
    await thread.readEarlier();

    expect(messages.pagesAsked, <int>[1]);
    expect(thread.hasEarlier, isFalse);

    thread.dispose();
  });

  // A line sent is held by the answer to the send and could be read again by
  // the next page, and it is one line either way.
  testWidgets('a line already held is not held a second time', (
    WidgetTester tester,
  ) async {
    final ThreadNotifier thread = open(MessagesDouble(lines: saidOver(3)));

    await thread.open();
    await thread.open();

    expect(thread.lines.length, 3);

    thread.dispose();
  });

  testWidgets('what was sent joins the thread as its newest line', (
    WidgetTester tester,
  ) async {
    final ThreadNotifier thread = open(MessagesDouble(lines: saidOver(3)));

    await thread.open();
    final bool sent = await thread.send('On our way.');

    expect(sent, isTrue);
    expect(thread.lines.first.body, 'On our way.');
    expect(thread.lines.length, 4);

    thread.dispose();
  });

  testWidgets('a refused send leaves the thread as it was and says why', (
    WidgetTester tester,
  ) async {
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

    thread.dispose();
  });

  // The row the list this thread was opened from is showing was read before
  // the reader was in it, so what the server holds afterwards goes back to it.
  testWidgets('the row read back after a write goes to whoever holds it', (
    WidgetTester tester,
  ) async {
    final ConversationsDouble conversations = ConversationsDouble()
      ..readsBack = thread(unreadCount: 0);
    final List<Conversation> reported = <Conversation>[];
    final List<int> counted = <int>[];

    final ThreadNotifier opened = open(
      MessagesDouble(lines: saidOver(2)),
      conversations: conversations,
      held: thread(unreadCount: 2),
      onThreadChanged: reported.add,
      onUnread: (Future<int> unread) async => counted.add(await unread),
    );

    await opened.open();

    expect(counted, <int>[0]);
    expect(reported.single.unreadCount, 0);
    expect(opened.thread.unreadCount, 0);

    opened.dispose();
  });

  testWidgets('a thread with nothing waiting is not marked read', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(2));
    final ThreadNotifier thread = open(messages);

    await thread.open();

    expect(messages.markedRead, isEmpty);

    thread.dispose();
  });

  testWidgets('a refused first read is reported and holds no lines', (
    WidgetTester tester,
  ) async {
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

    thread.dispose();
  });

  // What arrives over the hub is one more line in the thread, and one sent by
  // somebody else is one the reader has now seen.
  testWidgets('a line heard over the hub joins the thread and is marked read', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(2));
    final ChatHubDouble hub = ChatHubDouble();
    final ThreadNotifier thread = open(messages, hub: hub);

    await thread.open();
    hub.say(
      ChatSaid(
        line(
          id: 90,
          body: 'One more thing.',
          sentAt: DateTime.utc(2026, 9, 5, 12),
        ),
      ),
    );
    // Twice: the line arrives on the first, and what it sets off lands on the
    // second.
    await tester.pump();
    await tester.pump();

    expect(thread.lines.first.body, 'One more thing.');
    expect(messages.markedRead, <int>[7]);

    thread.dispose();
  });

  // A connection made after something was said would never be told about it.
  testWidgets('joining the hub reads the newest page again', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(2));
    final ChatHubDouble hub = ChatHubDouble();
    final ThreadNotifier thread = open(messages, hub: hub);

    await thread.open();
    hub.say(const ChatJoined());
    await tester.pump();

    expect(messages.pagesAsked, <int>[1, 1]);

    thread.dispose();
  });

  testWidgets('joining while a read is running queues one newest-page read', (
    WidgetTester tester,
  ) async {
    final List<Message> lines = saidOver(2);
    final MessagesDouble messages = MessagesDouble(
      lines: lines,
      holdsTheFirstRead: true,
    );
    final ChatHubDouble hub = ChatHubDouble();
    final ThreadNotifier thread = open(messages, hub: hub);

    final Future<void> opening = thread.open();
    await tester.pump();
    lines.insert(
      0,
      line(
        id: 90,
        body: 'Between the read and the join.',
        sentAt: DateTime.utc(2026, 9, 5, 12),
      ),
    );
    hub.say(const ChatJoined());
    await tester.pump();

    messages.answerFirstRead();
    await opening;
    await tester.pump();

    expect(messages.pagesAsked, <int>[1, 1]);
    expect(thread.lines.first.body, 'Between the read and the join.');

    thread.dispose();
  });

  // A thread the hub is not carrying is still a thread the reader is watching.
  testWidgets('a thread with no hub behind it reads itself on a timer', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(2));
    final ThreadNotifier thread = open(messages);

    await thread.open();
    await tester.pump(ThreadLiveness.refreshInterval);

    expect(messages.pagesAsked, <int>[1, 1]);

    thread.dispose();
  });

  testWidgets('a quietly found line from this account is not marked read', (
    WidgetTester tester,
  ) async {
    final List<Message> lines = saidOver(2);
    final MessagesDouble messages = MessagesDouble(lines: lines);
    final ThreadNotifier thread = open(messages);

    await thread.open();
    lines.insert(
      0,
      line(
        id: 90,
        senderUserId: reader,
        senderName: 'Emina Begić',
        body: 'Sent from another phone.',
        sentAt: DateTime.utc(2026, 9, 5, 12),
      ),
    );
    await tester.pump(ThreadLiveness.refreshInterval);
    await tester.pump();

    expect(thread.lines.first.body, 'Sent from another phone.');
    expect(messages.markedRead, isEmpty);

    thread.dispose();
  });

  testWidgets('a thread the hub is carrying is not read on a timer', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(2));
    final ChatHubDouble hub = ChatHubDouble();
    final ThreadNotifier thread = open(messages, hub: hub);

    await thread.open();
    hub.say(const ChatJoined());
    await tester.pump();
    messages.pagesAsked.clear();
    await tester.pump(ThreadLiveness.refreshInterval * 3);

    expect(messages.pagesAsked, isEmpty);

    thread.dispose();
  });

  testWidgets('a thread whose hub stream ends falls back to the timer', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(lines: saidOver(2));
    final ChatHubDouble hub = ChatHubDouble();
    final ThreadNotifier thread = open(messages, hub: hub);

    await thread.open();
    hub.say(const ChatJoined());
    await tester.pump();
    messages.pagesAsked.clear();

    await hub.endWatch();
    await tester.pump();
    await tester.pump(ThreadLiveness.refreshInterval);

    expect(messages.pagesAsked, <int>[1]);

    thread.dispose();
  });

  // A phone in a pocket holds no socket open, and coming back takes one again.
  testWidgets('the socket is given up behind the reader and taken again', (
    WidgetTester tester,
  ) async {
    final ChatHubDouble hub = ChatHubDouble();
    final ThreadNotifier thread = open(
      MessagesDouble(lines: saidOver(2)),
      hub: hub,
    );

    await thread.open();

    expect(hub.watched, <int>[7]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(hub.cancels, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(hub.watched, <int>[7, 7]);

    thread.dispose();
  });
}
