import 'package:json_annotation/json_annotation.dart';

import '../time/calendar_days.dart';
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
    this.experienceSlotStartTime,
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

  // When the term begins, answered beside the slot it names so that a list of
  // bookings says when each of them is without reading a term back per row.
  final DateTime? experienceSlotStartTime;

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

  // A booking there is nothing left to do to: called off, finished, or a stay
  // whose last night has gone. The two ends are read against the day the
  // reader is standing in, because a stay is measured in days rather than in
  // moments.
  bool isOverAt(DateTime now) =>
      standing == ReservationStatus.cancelled ||
      standing == ReservationStatus.completed ||
      (checkOutDate != null && !checkOutDate!.isAfter(CalendarDays.of(now)));

  // Whether a charge is worth offering on this booking, read from the row's
  // own fields against a clock: it is paid or not, over or not, and its hold
  // stands or has run out. Nothing here decides anything — the server opens a
  // charge or refuses one, and a refusal is shown as it comes — but a control
  // that would only earn a refusal is not put in front of a reader.
  //
  // This is the same mirror as the moves in [ReservationStatus], and it is on
  // the model rather than answered by the API because two thirds of it move
  // with the clock: a booking answered as payable sits in a list while its
  // hold runs out, and a row that carried the answer would be wrong by the
  // time the countdown beside it reached zero.
  bool canBePaidForAt(DateTime now) =>
      !isPaid && !isOverAt(now) && !_holdRanOutBy(now);

  bool _holdRanOutBy(DateTime now) =>
      standing == ReservationStatus.pending && !expiresAt.isAfter(now.toUtc());

  // A booking takes the nights between its two dates, so the day it ends on
  // belongs to the next guest: counting it paints a night nobody bought.
  bool occupies(DateTime day) {
    if (stay case (final DateTime arrival, final DateTime departure)) {
      return !day.isBefore(arrival) && day.isBefore(departure);
    }

    return false;
  }
}
