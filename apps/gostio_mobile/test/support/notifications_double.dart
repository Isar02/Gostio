import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/notifications/data/notifications_repository.dart';

// The two calls the bell and its screen are made of. It pages what it was
// given the way the server would, so a test names rows rather than pages.
class NotificationsDouble implements NotificationsRepository {
  NotificationsDouble({
    this.unread = 0,
    this.rows = const <AppNotification>[],
    this.failure,
  });

  final int unread;
  final List<AppNotification> rows;
  final ApiException? failure;

  int countCalls = 0;
  final List<int> pagesAsked = <int>[];

  @override
  Future<int> unreadCount() async {
    countCalls++;
    _refuseIfAsked();

    return unread;
  }

  @override
  Future<PagedResult<AppNotification>> search({
    required int page,
    required int pageSize,
  }) async {
    pagesAsked.add(page);
    _refuseIfAsked();

    final int from = ((page - 1) * pageSize).clamp(0, rows.length);
    final int to = (from + pageSize).clamp(0, rows.length);

    return PagedResult<AppNotification>(
      items: rows.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: rows.length,
    );
  }

  void _refuseIfAsked() {
    if (failure case final ApiException refused) {
      throw refused;
    }
  }
}
