import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/state/unread_count.dart';
import 'package:gostio_mobile/features/messages/presentation/unread_messages.dart';

import '../../../support/messages_double.dart';
import '../../../support/phone.dart';

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

  // Marking a thread read costs the server the same figure, so it is taken
  // from there rather than asked for again.
  testWidgets('a figure a write answered is taken over the one being polled', (
    WidgetTester tester,
  ) async {
    final UnreadMessages waiting = UnreadMessages(MessagesDouble(unread: 6));

    await tester.pump();
    waiting.report(2);
    await tester.pump(UnreadCount.pollInterval - const Duration(seconds: 1));

    expect(waiting.unread, 2);

    waiting.dispose();
  });
}
