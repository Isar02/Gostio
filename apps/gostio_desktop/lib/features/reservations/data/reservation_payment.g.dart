// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_payment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReservationPayment _$ReservationPaymentFromJson(Map<String, dynamic> json) =>
    ReservationPayment(
      id: (json['id'] as num).toInt(),
      reservationId: (json['reservationId'] as num).toInt(),
      status: json['status'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      processedAt: json['processedAt'] == null
          ? null
          : DateTime.parse(json['processedAt'] as String),
      failureReason: json['failureReason'] as String?,
    );
