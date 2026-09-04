import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// A filter nobody set is left out of the request rather than sent empty,
// which the API would read as a value to match.
@immutable
class ReservationQuery {
  const ReservationQuery({
    this.listing,
    this.reservationStatusId,
    this.isActive,
    this.from,
    this.to,
    this.arrivesOn,
    this.departsOn,
  });

  // One listing rather than two ids: the API narrows by accommodation and by
  // experience separately, and a booking is against one of the two.
  final ListingAddress? listing;

  final int? reservationStatusId;

  // Whether the booking still holds its place, which is the server's own
  // reading of a status and an expiry together.
  final bool? isActive;

  // The days a booking takes up, which is not the day it was written on.
  final DateTime? from;
  final DateTime? to;

  // A stay alone arrives and departs; a term is asked after through the window.
  final DateTime? arrivesOn;
  final DateTime? departsOn;

  bool get isEmpty => toParameters().isEmpty;

  JsonMap toParameters() => <String, dynamic>{
    'accommodationId': ?_idOf(ListingKind.accommodation),
    'experienceId': ?_idOf(ListingKind.experience),
    'reservationStatusId': ?reservationStatusId,
    'isActive': ?isActive,
    'from': ?_day(from),
    'to': ?_day(to),
    'arrivesOn': ?_day(arrivesOn),
    'departsOn': ?_day(departsOn),
  };

  @override
  bool operator ==(Object other) =>
      other is ReservationQuery &&
      other.listing == listing &&
      other.reservationStatusId == reservationStatusId &&
      other.isActive == isActive &&
      other.from == from &&
      other.to == to &&
      other.arrivesOn == arrivesOn &&
      other.departsOn == departsOn;

  @override
  int get hashCode => Object.hash(
    listing,
    reservationStatusId,
    isActive,
    from,
    to,
    arrivesOn,
    departsOn,
  );

  int? _idOf(ListingKind kind) {
    final ListingAddress? chosen = listing;

    return chosen == null || chosen.kind != kind ? null : chosen.id;
  }

  static String? _day(DateTime? day) =>
      day == null ? null : CalendarDays.write(day);
}
