import 'package:json_annotation/json_annotation.dart';

part 'reservation_payment.g.dart';

// What the processor did with the charge. The two secrets a card sheet opens
// on are handed out only to the guest who is paying and only while the charge
// is still open, so a payment that is merely read answers neither of them.
@JsonSerializable(createToJson: false)
class ReservationPayment {
  const ReservationPayment({
    required this.id,
    required this.reservationId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createdAt,
    this.clientSecret,
    this.publishableKey,
    this.processedAt,
    this.failureReason,
  });

  factory ReservationPayment.fromJson(Map<String, dynamic> json) =>
      _$ReservationPaymentFromJson(json);

  final int id;
  final int reservationId;
  final String status;
  final double amount;
  final String currency;
  final String? clientSecret;
  final String? publishableKey;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? failureReason;
}
