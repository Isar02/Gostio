import 'package:gostio_core/gostio_core.dart';

// A notice the way the API answers one. Its age is relative so that what a
// card prints beside it is stable whenever the suite is run.
AppNotification notice({
  int id = 1,
  NotificationKind kind = NotificationKind.reservationCreated,
  String title = 'Booking confirmed',
  String body = 'Your stay in Mostar is confirmed for 12 June.',
  bool isRead = false,
  Duration age = const Duration(hours: 2),
  int? reservationId = 314,
}) => AppNotification(
  id: id,
  kind: kind,
  title: title,
  body: body,
  isRead: isRead,
  createdAt: DateTime.now().toUtc().subtract(age),
  reservationId: reservationId,
);

List<AppNotification> notices(int count) => <AppNotification>[
  for (int index = 1; index <= count; index++)
    notice(id: index, title: 'Notice $index'),
];
