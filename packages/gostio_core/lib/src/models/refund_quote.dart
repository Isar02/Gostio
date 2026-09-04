import 'package:json_annotation/json_annotation.dart';

part 'refund_quote.g.dart';

// What calling a booking off would send back, read while calling it off is
// still a choice. It moves with the clock until the cancellation, so it is
// asked for when the dialog opens rather than held from the page load.
@JsonSerializable(createToJson: false)
class RefundQuote {
  const RefundQuote({
    required this.reservationId,
    required this.isPaid,
    required this.charged,
    required this.currency,
    required this.percentage,
    required this.amount,
    required this.reason,
    required this.graceEndsAt,
    required this.asOf,
  });

  factory RefundQuote.fromJson(Map<String, dynamic> json) =>
      _$RefundQuoteFromJson(json);

  final int reservationId;

  // False while nothing has been charged, and the amount is then what the
  // policy would give back on the price as it stands rather than money.
  final bool isPaid;

  final double charged;
  final String currency;
  final int percentage;
  final double amount;
  final String reason;
  final DateTime graceEndsAt;
  final DateTime asOf;
}
