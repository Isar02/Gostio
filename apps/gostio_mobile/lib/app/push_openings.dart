import 'dart:async';

import 'package:flutter/material.dart';

import '../core/push/push_messaging.dart';
import '../core/push/push_notice.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import 'named_trip_screen.dart';

// What a delivered notice opens when the reader taps it. It is composed here
// rather than inside the shell because the shell's job is which tab is in front
// and what Back means; where a notice leads is a question about three features
// and belongs beside the screen that answers it.
//
// The navigator is asked for rather than held, because the tab a tap should
// open in is the tab the reader is in at the moment it arrives.
class PushOpenings {
  PushOpenings(PushMessaging messaging, {required this.into}) {
    _taps = messaging.opened.listen(_open);
  }

  final NavigatorState? Function() into;

  StreamSubscription<PushNotice>? _taps;

  void dispose() {
    unawaited(_taps?.cancel());
    _taps = null;
  }

  // A notice names a booking, or it names nothing — a host verification is the
  // one kind that carries no reservation. The first opens the booking and the
  // second opens the notices, so a tap always arrives somewhere rather than
  // being a gesture that sometimes does nothing.
  void _open(PushNotice notice) {
    final NavigatorState? navigator = into();
    if (navigator == null || !navigator.mounted) {
      return;
    }

    final int? reservationId = notice.reservationId;

    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => reservationId == null
              ? const NotificationsScreen(openBooking: NamedTripScreen.open)
              : NamedTripScreen(reservationId),
        ),
      ),
    );
  }
}
