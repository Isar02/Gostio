import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/messages/presentation/chat_unread_notifier.dart';

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

  test('a count that could not be read leaves the badge as it was', () async {
    final MessagesDouble messages = MessagesDouble(unread: 2);
    final ChatUnreadNotifier waiting = _waiting(messages);

    await waiting.refresh();

    messages.failing = true;
    await waiting.refresh();

    expect(waiting.unread, 2);
  });
}

ChatUnreadNotifier _waiting(MessagesDouble messages) {
  final ChatUnreadNotifier waiting = ChatUnreadNotifier(messages);
  addTearDown(waiting.dispose);

  return waiting;
}
