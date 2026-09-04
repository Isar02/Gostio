import 'package:json_annotation/json_annotation.dart';

part 'reservation_payment.g.dart';

// What the processor did with the charge. The client secret and the key that
// open a card sheet are the guest's alone, so nothing here reads them: this
// client watches a charge rather than making one.
@JsonSerializable(createToJson: false)
class ReservationPayment {
  const ReservationPayment({
    required this.id,
    required this.reservationId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createdAt,
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
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? failureReason;
}
