import 'package:json_annotation/json_annotation.dart';

part 'reservation_refund.g.dart';

@JsonSerializable(createToJson: false)
class ReservationRefund {
  const ReservationRefund({
    required this.id,
    required this.reservationId,
    required this.paymentId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.reason,
    required this.createdAt,
    this.processedAt,
    this.failureReason,
  });

  factory ReservationRefund.fromJson(Map<String, dynamic> json) =>
      _$ReservationRefundFromJson(json);

  final int id;
  final int reservationId;
  final int paymentId;
  final String status;
  final double amount;
  final String currency;

  // Which rule of the cancellation policy decided the amount, which is a
  // different sentence from why the booking was called off.
  final String reason;

  final DateTime createdAt;
  final DateTime? processedAt;
  final String? failureReason;
}
