import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/state/foreground_poll.dart';
import 'package:gostio_mobile/features/messages/presentation/chat_nudge.dart';
import 'package:gostio_mobile/features/messages/presentation/unread_messages.dart';

import '../../../support/messages_double.dart';
import '../../../support/phone.dart';

class _DeferredCounts extends MessagesDouble {
  final List<Completer<int>> answers = <Completer<int>>[];

  @override
  Future<int> unreadCount() {
    countCalls++;
    final Completer<int> answer = Completer<int>();
    answers.add(answer);

    return answer.future;
  }
}

// The count is built inside a widget test because its poll runs on the clock
// the test binding controls, and it is ended inside the test body because the
// binding looks for a pending timer before a tear-down could cancel one.
void main() {
  setUp(usePhoneScreen);

  testWidgets('the inbox count is read as soon as there is an account', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(unread: 6);
    final UnreadMessages waiting = UnreadMessages(messages);

    await tester.pump();

    expect(waiting.unread, 6);
    expect(messages.countCalls, 1);

    waiting.dispose();
  });

  // The interval is thirty seconds. What the hub says arrives at once.
  testWidgets('a nudge from the hub counts again without waiting', (
    WidgetTester tester,
  ) async {
    final MessagesDouble messages = MessagesDouble(unread: 0);
    final ChatHubDouble hub = ChatHubDouble();
    final ChatNudge nudge = ChatNudge(hub);
    final UnreadMessages waiting = UnreadMessages(messages, nudge: nudge);

    await tester.pump();
    expect(messages.countCalls, 1);

    messages.unread = 3;
    await hub.touch(7);
    await tester.pump();

    expect(waiting.unread, 3);
    expect(messages.countCalls, 2);

    waiting.dispose();
    nudge.dispose();
    await hub.close();
  });

  // Marking a thread read costs the server the same figure, so it is taken
  // from there rather than asked for again.
  testWidgets('a figure a write answered is taken over the one being polled', (
    WidgetTester tester,
  ) async {
    final UnreadMessages waiting = UnreadMessages(MessagesDouble(unread: 6));

    await tester.pump();
    await waiting.report(Future<int>.value(2));
    await tester.pump(ForegroundPoll.interval - const Duration(seconds: 1));

    expect(waiting.unread, 2);

    waiting.dispose();
  });

  testWidgets('a later poll is not overwritten by an older write answer', (
    WidgetTester tester,
  ) async {
    final _DeferredCounts messages = _DeferredCounts();
    final UnreadMessages waiting = UnreadMessages(messages);

    messages.answers.single.complete(6);
    await tester.pump();

    final Completer<int> write = Completer<int>();
    final Future<void> reporting = waiting.report(write.future);
    await tester.pump(ForegroundPoll.interval);
    messages.answers.last.complete(4);
    await tester.pump();

    write.complete(2);
    await reporting;

    expect(waiting.unread, 4);

    waiting.dispose();
  });
}
