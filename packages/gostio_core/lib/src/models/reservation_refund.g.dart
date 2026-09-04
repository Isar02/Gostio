// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_refund.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReservationRefund _$ReservationRefundFromJson(Map<String, dynamic> json) =>
    ReservationRefund(
      id: (json['id'] as num).toInt(),
      reservationId: (json['reservationId'] as num).toInt(),
      paymentId: (json['paymentId'] as num).toInt(),
      status: json['status'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      processedAt: json['processedAt'] == null
          ? null
          : DateTime.parse(json['processedAt'] as String),
      failureReason: json['failureReason'] as String?,
    );
