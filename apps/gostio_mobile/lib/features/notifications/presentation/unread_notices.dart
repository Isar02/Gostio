import 'dart:async';

import '../../../core/push/push_messaging.dart';
import '../../../core/push/push_notice.dart';
import '../../../core/state/unread_count.dart';
import '../data/notifications_repository.dart';

// One count for the whole client. Every tab draws the same bell, so the number
// behind it is read once here rather than once per tab.
//
// A delivery that arrives while the reader is in front of the application draws
// nothing over what they are reading; it moves this figure, which is the tab
// bar telling them there is something new without taking the screen off them.
class UnreadNotices extends UnreadCount {
  UnreadNotices(this._repository, {PushMessaging? messaging}) {
    _arrivals = messaging?.arrivals.listen(
      (PushNotice _) => unawaited(refresh()),
    );
  }

  final NotificationsRepository _repository;

  StreamSubscription<PushNotice>? _arrivals;

  @override
  Future<int> read() => _repository.unreadCount();

  @override
  void dispose() {
    unawaited(_arrivals?.cancel());

    super.dispose();
  }
}
