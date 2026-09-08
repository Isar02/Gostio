import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/messages/presentation/chat_unread_notifier.dart';

import '../../../support/chat_doubles.dart';
import '../../../support/conversation_doubles.dart';

void main() {
  test('the badge holds what the API counted', () async {
    final ChatUnreadNotifier waiting = _waiting(MessagesDouble(unread: 3));

    await waiting.refresh();

    expect(waiting.unread, 3);
  });

  // Marking a thread read answers with the same number, and an answer to a
  // count asked for before that is stale by the time it lands.
  test(
    'what the marking answered outlives a count already in flight',
    () async {
      final MessagesDouble messages = MessagesDouble(unread: 3);
      final ChatUnreadNotifier waiting = _waiting(messages);

      final Future<void> counting = waiting.refresh();
      waiting.report(0);
      await counting;

      expect(waiting.unread, 0);
    },
  );

  // The badge counts the kind the panel it sits in lists.
  test('the badge counts the kind the panel it sits in lists', () async {
    final MessagesDouble messages = MessagesDouble(unread: 3);
    final ChatUnreadNotifier waiting = _waiting(messages);

    await waiting.refresh();
    expect(messages.scopes.last, isNull);

    await waiting.scopeTo(ConversationType.direct);

    expect(messages.scopes.last, ConversationType.direct);
  });

  // The interval is the fallback; the hub keeps this current.
  test('a nudge from the hub counts again', () async {
    final MessagesDouble messages = MessagesDouble(unread: 3);
    final ChatHubDouble hub = ChatHubDouble();
    final ChatUnreadNotifier waiting = _waiting(messages, hub: hub);

    await waiting.refresh();

    final int countedSoFar = messages.scopes.length;

    await hub.touch(4);
    await Future<void>.delayed(Duration.zero);

    expect(messages.scopes.length, greaterThan(countedSoFar));

    await hub.close();
  });

  // The marking answers for the whole account. A host badge counting one kind
  // that took that number would put the support it does not list back on.
  test('a scoped badge does not take the number a marking answered', () async {
    final MessagesDouble messages = MessagesDouble(unread: 7);
    final ChatUnreadNotifier waiting = _waiting(messages);

    await waiting.scopeTo(ConversationType.direct);

    messages.unread = 0;
    waiting.report(7);
    await Future<void>.delayed(Duration.zero);

    expect(waiting.unread, 0);
    expect(messages.scopes.last, ConversationType.direct);
  });

  test('a count that could not be read leaves the badge as it was', () async {
    final MessagesDouble messages = MessagesDouble(unread: 2);
    final ChatUnreadNotifier waiting = _waiting(messages);

    await waiting.refresh();

    messages.failing = true;
    await waiting.refresh();

    expect(waiting.unread, 2);
  });
}

ChatUnreadNotifier _waiting(MessagesDouble messages, {ChatHubDouble? hub}) {
  final ChatUnreadNotifier waiting = ChatUnreadNotifier(messages, hub: hub);
  addTearDown(waiting.dispose);

  return waiting;
}
