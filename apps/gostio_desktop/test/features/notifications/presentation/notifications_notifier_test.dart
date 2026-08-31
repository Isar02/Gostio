import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/notifications/data/app_notification.dart';
import 'package:gostio_desktop/features/notifications/data/notifications_repository.dart';
import 'package:gostio_desktop/features/notifications/presentation/notification_filter.dart';
import 'package:gostio_desktop/features/notifications/presentation/notifications_notifier.dart';

void main() {
  test(
    'a failed filter change keeps the rows and their filter together',
    () async {
      final _FakeNotificationsRepository repository =
          _FakeNotificationsRepository(<AppNotification>[
            _notification(1, isRead: true),
            _notification(2),
          ]);
      final NotificationsNotifier notifier = NotificationsNotifier(repository);
      addTearDown(notifier.dispose);

      await notifier.load();
      repository.failNextSearch = true;
      await notifier.show(NotificationFilter.unread);

      expect(notifier.filter, NotificationFilter.all);
      expect(notifier.items.map((AppNotification item) => item.id), <int>[
        1,
        2,
      ]);
      expect(notifier.failureMessage, 'Search failed.');
    },
  );
}

AppNotification _notification(int id, {bool isRead = false}) => AppNotification(
  id: id,
  kind: NotificationKind.reservationCreated,
  title: 'Notification $id',
  body: 'Body $id',
  isRead: isRead,
  createdAt: DateTime.utc(2026, 1, 1),
  readAt: isRead ? DateTime.utc(2026, 1, 2) : null,
);

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository(this.notifications);

  final List<AppNotification> notifications;

  bool failNextSearch = false;

  @override
  Future<int> unreadCount() async =>
      notifications.where((AppNotification item) => !item.isRead).length;

  @override
  Future<PagedResult<AppNotification>> search({
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    bool? isRead,
  }) async {
    if (failNextSearch) {
      failNextSearch = false;
      throw const ApiException(message: 'Search failed.');
    }

    final List<AppNotification> matches = notifications
        .where(
          (AppNotification item) => isRead == null || item.isRead == isRead,
        )
        .toList(growable: false);
    final int first = (page - 1) * pageSize;
    final List<AppNotification> items = first >= matches.length
        ? const <AppNotification>[]
        : matches.sublist(
            first,
            first + pageSize < matches.length
                ? first + pageSize
                : matches.length,
          );

    return PagedResult<AppNotification>(
      items: items,
      page: page,
      pageSize: pageSize,
      totalCount: matches.length,
    );
  }

  @override
  Future<void> markRead(int id) async {
    final int index = notifications.indexWhere(
      (AppNotification item) => item.id == id,
    );
    final AppNotification item = notifications[index];
    notifications[index] = AppNotification(
      id: item.id,
      kind: item.kind,
      title: item.title,
      body: item.body,
      isRead: true,
      createdAt: item.createdAt,
      reservationId: item.reservationId,
      readAt: DateTime.utc(2026, 1, 2),
    );
  }

  @override
  Future<void> markAllRead() async {
    for (final AppNotification item in List<AppNotification>.of(
      notifications,
    )) {
      await markRead(item.id);
    }
  }
}
