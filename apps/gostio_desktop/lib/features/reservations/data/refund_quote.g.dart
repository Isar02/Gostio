// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refund_quote.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RefundQuote _$RefundQuoteFromJson(Map<String, dynamic> json) => RefundQuote(
  reservationId: (json['reservationId'] as num).toInt(),
  isPaid: json['isPaid'] as bool,
  charged: (json['charged'] as num).toDouble(),
  currency: json['currency'] as String,
  percentage: (json['percentage'] as num).toInt(),
  amount: (json['amount'] as num).toDouble(),
  reason: json['reason'] as String,
  graceEndsAt: DateTime.parse(json['graceEndsAt'] as String),
  asOf: DateTime.parse(json['asOf'] as String),
);
