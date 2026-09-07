import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/notifications/data/notifications_repository.dart';

import 'notice_fixture.dart';

// The calls the bell, its screen and this device's registration are made of.
// It pages what it was given the way the server would, so a test names rows
// rather than pages.
class NotificationsDouble implements NotificationsRepository {
  NotificationsDouble({
    this.unread = 0,
    this.rows = const <AppNotification>[],
    this.failure,
    this.writeFailure,
    this.deviceFailure,
    AppNotification? read,
    this.unreadAfterMarkAll = 0,
  }) : read = read ?? notice(isRead: true);

  final int unread;

  // Not final: a test moves the server on between two reads, which is what a
  // list that keeps itself current is for.
  List<AppNotification> rows;
  final ApiException? failure;

  // A write refused where the reads are not, which is the pair the screen has
  // to keep apart.
  final ApiException? writeFailure;
  final ApiException? deviceFailure;
  final AppNotification read;
  final int unreadAfterMarkAll;

  int countCalls = 0;
  final List<int> pagesAsked = <int>[];
  final List<int> markedRead = <int>[];
  int markAllCalls = 0;
  final List<String> registered = <String>[];
  final List<String> forgotten = <String>[];

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

  @override
  Future<AppNotification> markRead(int id) async {
    markedRead.add(id);
    _refuseWriteIfAsked();

    return read;
  }

  @override
  Future<int> markAllRead() async {
    markAllCalls++;
    _refuseWriteIfAsked();

    return unreadAfterMarkAll;
  }

  @override
  Future<void> registerDevice(String token) async {
    registered.add(token);

    if (deviceFailure case final ApiException refused) {
      throw refused;
    }
  }

  @override
  Future<void> forgetDevice(String token) async {
    forgotten.add(token);

    if (deviceFailure case final ApiException refused) {
      throw refused;
    }
  }

  void _refuseIfAsked() {
    if (failure case final ApiException refused) {
      throw refused;
    }
  }

  void _refuseWriteIfAsked() {
    if (writeFailure case final ApiException refused) {
      throw refused;
    }
  }
}
