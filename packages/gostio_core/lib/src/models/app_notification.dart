import 'package:json_annotation/json_annotation.dart';

part 'app_notification.g.dart';

// The API names these after what raised them. An unknown value is a server
// this build has not caught up with, not a reason to drop the row.
enum NotificationKind {
  @JsonValue('ReservationCreated')
  reservationCreated,
  @JsonValue('ReservationStatusChanged')
  reservationStatusChanged,
  @JsonValue('PaymentSucceeded')
  paymentSucceeded,
  @JsonValue('RefundProcessed')
  refundProcessed,
  @JsonValue('HostVerificationDecided')
  hostVerificationDecided,
  unknown,
}

@JsonSerializable(createToJson: false)
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.reservationId,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  final int id;

  @JsonKey(name: 'type', unknownEnumValue: NotificationKind.unknown)
  final NotificationKind kind;

  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final int? reservationId;
  final DateTime? readAt;
}
