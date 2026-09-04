import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/messages/data/conversation_query.dart';
import 'package:gostio_desktop/features/messages/presentation/inbox_notifier.dart';

import '../../../support/conversation_doubles.dart';
import '../../../support/conversation_fixture.dart';

void main() {
  test('a kind is applied from the first page', () async {
    final ConversationsDouble threads = _threads(totalCount: 60);
    final InboxNotifier inbox = _inbox(threads);

    await inbox.openPage(3);
    await inbox.apply(const ConversationQuery(type: ConversationType.support));

    expect(inbox.page, 1);
    expect(threads.pages, <int>[3, 1]);
    expect(threads.queries.last.toParameters(), <String, dynamic>{
      'type': 'Support',
    });
  });

  // An administrator sees the whole support queue unless they ask for the
  // threads they are in, and that is carried through every page and filter.
  test(
    'whose threads these are is carried through paging and filtering',
    () async {
      final ConversationsDouble threads = _threads(totalCount: 60);
      final InboxNotifier inbox = InboxNotifier(
        threads,
        query: const ConversationQuery(joinedBy: administratorId),
      );
      addTearDown(inbox.dispose);

      await inbox.reload();
      await inbox.apply(inbox.query.withType(ConversationType.direct));
      await inbox.openPage(2);

      for (final ConversationQuery asked in threads.queries) {
        expect(asked.joinedBy, administratorId);
      }
    },
  );

  // The inbox reads itself again on a timer, and a timer is not a reader: it
  // draws no bar on the way and says nothing when it lands.
  test('a refresh nobody asked for announces nothing until it lands', () async {
    final ConversationsDouble threads = _threads();
    final InboxNotifier inbox = _inbox(threads);

    await inbox.reload();

    var announced = 0;
    inbox.addListener(() => announced++);

    threads.rows = <Conversation>[
      conversation(id: 7, unreadCount: 0),
      conversation(id: 9, unreadCount: 2),
    ];
    threads.totalCount = 2;

    await inbox.refreshQuietly();

    expect(announced, 1);
    expect(inbox.isLoading, isFalse);
    expect(inbox.items, hasLength(2));
  });

  test('a refresh that failed leaves the threads and says nothing', () async {
    final ConversationsDouble threads = _threads();
    final InboxNotifier inbox = _inbox(threads);

    await inbox.reload();

    threads.failing = true;
    await inbox.refreshQuietly();

    expect(inbox.failureMessage, isNull);
    expect(inbox.items, hasLength(1));
  });

  test(
    'the thread on the right is handed back as the inbox last read it',
    () async {
      final ConversationsDouble threads = _threads();
      final InboxNotifier inbox = _inbox(threads);

      await inbox.reload();

      expect(inbox.holding(7)?.unreadCount, 1);
      expect(inbox.holding(404), isNull);
    },
  );
}

ConversationsDouble _threads({int? totalCount}) => ConversationsDouble(
  rows: <Conversation>[conversation()],
  totalCount: totalCount,
);

InboxNotifier _inbox(ConversationsDouble threads) {
  final InboxNotifier inbox = InboxNotifier(
    threads,
    query: const ConversationQuery(),
  );
  addTearDown(inbox.dispose);

  return inbox;
}
