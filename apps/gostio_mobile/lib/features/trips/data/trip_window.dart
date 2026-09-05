import 'package:gostio_core/gostio_core.dart';

// The two lists a guest reads their bookings in, and the one day that tells
// them apart: a booking with a day still to come is ahead of the reader, and
// one whose last day has gone is behind them.
//
// The server answers the two sides as exact opposites of each other, so a
// booking belongs to one of these lists and never to both — a stay the reader
// is on today is ahead of them rather than in each list once.
enum TripWindow {
  upcoming(
    label: 'Upcoming',
    emptyTitle: 'Nothing booked yet',
    emptyMessage:
        'Stays and experiences you book appear here, with what is still owed '
        'on them.',
  ),
  past(
    label: 'Past',
    emptyTitle: 'Nothing behind you yet',
    emptyMessage: 'A booking moves here the day after its last day.',
  );

  const TripWindow({
    required this.label,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final String label;
  final String emptyTitle;
  final String emptyMessage;

  // Asked against the day the reader is standing in rather than one stored
  // when the list was made, so a client left open overnight asks the new day's
  // question the next time it reads a page.
  JsonMap boundedOn(DateTime today) => switch (this) {
    TripWindow.upcoming => <String, dynamic>{'from': CalendarDays.write(today)},
    TripWindow.past => <String, dynamic>{
      'endedBefore': CalendarDays.write(today),
    },
  };
}
