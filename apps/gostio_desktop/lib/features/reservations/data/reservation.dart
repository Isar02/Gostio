import 'package:json_annotation/json_annotation.dart';

import 'reservation_status.dart';

part 'reservation.g.dart';

@JsonSerializable(createToJson: false)
class Reservation {
  const Reservation({
    required this.id,
    required this.userId,
    required this.guestName,
    required this.listingTitle,
    required this.guestCount,
    required this.reservationStatusId,
    required this.status,
    required this.totalPrice,
    required this.isPaid,
    required this.expiresAt,
    required this.createdAt,
    this.accommodationId,
    this.experienceId,
    this.experienceSlotId,
    this.checkInDate,
    this.checkOutDate,
    this.accommodationTotal,
    this.cleaningFee,
    this.pricePerPerson,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) =>
      _$ReservationFromJson(json);

  final int id;
  final int userId;
  final String guestName;
  final String listingTitle;
  final int guestCount;
  final int reservationStatusId;
  final String status;
  final double totalPrice;
  final bool isPaid;

  // When a hold stops holding its place, which only a pending booking is under.
  final DateTime expiresAt;

  final DateTime createdAt;

  // Exactly one of the two is answered: a booking is against a stay or a term.
  final int? accommodationId;
  final int? experienceId;
  final int? experienceSlotId;

  // A term names a slot rather than two dates, so a stay is what carries both.
  final DateTime? checkInDate;
  final DateTime? checkOutDate;

  // The three parts a total is made of, each of them the side of the catalogue
  // it belongs to: a stay is nights plus cleaning, a term is a price a head.
  final double? accommodationTotal;
  final double? cleaningFee;
  final double? pricePerPerson;

  ReservationStatus? get standing =>
      ReservationStatus.forId(reservationStatusId);

  bool get isTerm => experienceSlotId != null;

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
