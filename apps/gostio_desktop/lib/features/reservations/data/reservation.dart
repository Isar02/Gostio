import 'package:json_annotation/json_annotation.dart';

import 'reservation_status.dart';

part 'reservation.g.dart';

@JsonSerializable(createToJson: false)
class Reservation {
  const Reservation({
    required this.id,
    required this.guestName,
    required this.guestCount,
    required this.reservationStatusId,
    required this.status,
    this.checkInDate,
    this.checkOutDate,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) =>
      _$ReservationFromJson(json);

  final int id;
  final String guestName;
  final int guestCount;
  final int reservationStatusId;
  final String status;

  // A term names a slot rather than two dates, so a stay is what carries both.
  final DateTime? checkInDate;
  final DateTime? checkOutDate;

  ReservationStatus? get standing =>
      ReservationStatus.forId(reservationStatusId);

  // The two dates a stay is measured by, together or not at all.
  (DateTime, DateTime)? get stay {
    final DateTime? arrival = checkInDate;
    final DateTime? departure = checkOutDate;

    return arrival == null || departure == null ? null : (arrival, departure);
  }

  // A booking takes the nights between its two dates, so the day it ends on
  // belongs to the next guest: counting it paints a night nobody bought.
  bool occupies(DateTime day) {
    if (stay case (final DateTime arrival, final DateTime departure)) {
      return !day.isBefore(arrival) && day.isBefore(departure);
    }

    return false;
  }
}
