import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/notifications/data/notifications_repository.dart';

// The rows the API is holding, marked read in place.
class NotificationsDouble implements NotificationsRepository {
  NotificationsDouble(this.notifications);

  final List<AppNotification> notifications;

  bool failNextSearch = false;

  int searches = 0;

  @override
  Future<int> unreadCount() async =>
      notifications.where((AppNotification item) => !item.isRead).length;

  @override
  Future<PagedResult<AppNotification>> search({
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
    bool? isRead,
  }) async {
    searches++;

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

AppNotification aNotification(int id, {bool isRead = false}) => AppNotification(
  id: id,
  kind: NotificationKind.reservationCreated,
  title: 'Notification $id',
  body: 'Body $id',
  isRead: isRead,
  createdAt: DateTime.utc(2026, 1, 1),
  readAt: isRead ? DateTime.utc(2026, 1, 2) : null,
);
