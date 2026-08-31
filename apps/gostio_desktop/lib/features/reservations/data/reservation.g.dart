// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Reservation _$ReservationFromJson(Map<String, dynamic> json) => Reservation(
  id: (json['id'] as num).toInt(),
  guestName: json['guestName'] as String,
  guestCount: (json['guestCount'] as num).toInt(),
  reservationStatusId: (json['reservationStatusId'] as num).toInt(),
  status: json['status'] as String,
  checkInDate: json['checkInDate'] == null
      ? null
      : DateTime.parse(json['checkInDate'] as String),
  checkOutDate: json['checkOutDate'] == null
      ? null
      : DateTime.parse(json['checkOutDate'] as String),
);
