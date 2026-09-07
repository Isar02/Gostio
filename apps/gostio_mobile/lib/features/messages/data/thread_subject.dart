import 'package:flutter/foundation.dart';

// What opening a thread is addressed to. The API takes an account or a booking
// and refuses both at once, so the pair is one type rather than two nullable
// ids a caller could fill in together, and support is a route of its own.
@immutable
sealed class ThreadSubject {
  const ThreadSubject();
}

final class WithHost extends ThreadSubject {
  const WithHost(this.hostId);

  final int hostId;
}

final class AboutBooking extends ThreadSubject {
  const AboutBooking(this.reservationId);

  final int reservationId;
}

final class WithSupport extends ThreadSubject {
  const WithSupport();
}
