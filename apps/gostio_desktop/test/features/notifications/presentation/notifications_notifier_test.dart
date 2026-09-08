import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/notifications/presentation/notification_filter.dart';
import 'package:gostio_desktop/features/notifications/presentation/notifications_notifier.dart';

import '../../../support/notifications_double.dart';

void main() {
  test(
    'a failed filter change keeps the rows and their filter together',
    () async {
      final NotificationsDouble repository = NotificationsDouble(
        <AppNotification>[aNotification(1, isRead: true), aNotification(2)],
      );
      final NotificationsNotifier notifier = NotificationsNotifier(repository);
      addTearDown(notifier.dispose);

      await notifier.reload();
      repository.failNextSearch = true;
      await notifier.apply(NotificationFilter.unread);

      expect(notifier.query, NotificationFilter.all);
      expect(notifier.items.map((AppNotification item) => item.id), <int>[
        1,
        2,
      ]);
      expect(notifier.failureMessage, 'Search failed.');
    },
  );

  // The badge kept up on its own while the list under it did not, so a panel
  // left open showed rows the count already disagreed with.
  test('an open panel reads the rows the interval counts', () async {
    final NotificationsDouble repository = NotificationsDouble(
      <AppNotification>[aNotification(1)],
    );
    final NotificationsNotifier notifier = NotificationsNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.reload();
    expect(notifier.items.map((AppNotification item) => item.id), <int>[1]);

    notifier.watch();
    repository.notifications.add(aNotification(2));

    await notifier.poll();

    expect(notifier.unread, 2);
    expect(notifier.items.map((AppNotification item) => item.id), <int>[1, 2]);
  });

  // A list nobody is looking at is a request every interval for an answer
  // nobody reads. The badge is the one thing that still has to keep up.
  test('a closed panel counts without reading the rows', () async {
    final NotificationsDouble repository = NotificationsDouble(
      <AppNotification>[aNotification(1)],
    );
    final NotificationsNotifier notifier = NotificationsNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.reload();

    final int readSoFar = repository.searches;

    repository.notifications.add(aNotification(2));

    await notifier.poll();

    expect(notifier.unread, 2);
    expect(repository.searches, readSoFar);
    expect(notifier.items.map((AppNotification item) => item.id), <int>[1]);
  });

  test('a panel closed again stops reading the rows', () async {
    final NotificationsDouble repository = NotificationsDouble(
      <AppNotification>[aNotification(1)],
    );
    final NotificationsNotifier notifier = NotificationsNotifier(repository);
    addTearDown(notifier.dispose);

    await notifier.reload();

    notifier.watch();
    expect(notifier.isOnScreen, isTrue);

    notifier.unwatch();
    expect(notifier.isOnScreen, isFalse);

    final int readSoFar = repository.searches;

    await notifier.poll();

    expect(repository.searches, readSoFar);
  });

  test(
    'marking the last row returns to the last page that still exists',
    () async {
      final NotificationsDouble repository = NotificationsDouble(
        <AppNotification>[for (int id = 1; id <= 21; id++) aNotification(id)],
      );
      final NotificationsNotifier notifier = NotificationsNotifier(repository);
      addTearDown(notifier.dispose);

      await notifier.apply(NotificationFilter.unread);
      await notifier.openPage(2);
      expect(notifier.items, hasLength(1));

      await notifier.markRead(notifier.items.single);

      expect(notifier.page, 1);
      expect(notifier.totalCount, 20);
      expect(notifier.items, hasLength(20));
      expect(
        notifier.items.every((AppNotification item) => !item.isRead),
        isTrue,
      );
    },
  );
}
