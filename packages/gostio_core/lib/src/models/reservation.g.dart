// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Reservation _$ReservationFromJson(Map<String, dynamic> json) => Reservation(
  id: (json['id'] as num).toInt(),
  userId: (json['userId'] as num).toInt(),
  guestName: json['guestName'] as String,
  listingTitle: json['listingTitle'] as String,
  guestCount: (json['guestCount'] as num).toInt(),
  reservationStatusId: (json['reservationStatusId'] as num).toInt(),
  status: json['status'] as String,
  totalPrice: (json['totalPrice'] as num).toDouble(),
  isPaid: json['isPaid'] as bool,
  expiresAt: DateTime.parse(json['expiresAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  accommodationId: (json['accommodationId'] as num?)?.toInt(),
  experienceId: (json['experienceId'] as num?)?.toInt(),
  experienceSlotId: (json['experienceSlotId'] as num?)?.toInt(),
  checkInDate: json['checkInDate'] == null
      ? null
      : DateTime.parse(json['checkInDate'] as String),
  checkOutDate: json['checkOutDate'] == null
      ? null
      : DateTime.parse(json['checkOutDate'] as String),
  accommodationTotal: (json['accommodationTotal'] as num?)?.toDouble(),
  cleaningFee: (json['cleaningFee'] as num?)?.toDouble(),
  pricePerPerson: (json['pricePerPerson'] as num?)?.toDouble(),
);
