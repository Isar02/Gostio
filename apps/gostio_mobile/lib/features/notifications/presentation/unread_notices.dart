import '../../../core/state/unread_count.dart';
import '../data/notifications_repository.dart';

// One count for the whole client. Every tab draws the same bell, so the number
// behind it is read once here rather than once per tab.
class UnreadNotices extends UnreadCount {
  UnreadNotices(this._repository);

  final NotificationsRepository _repository;

  @override
  Future<int> read() => _repository.unreadCount();
}
