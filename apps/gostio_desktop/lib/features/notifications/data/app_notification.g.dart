// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_notification.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppNotification _$AppNotificationFromJson(Map<String, dynamic> json) =>
    AppNotification(
      id: (json['id'] as num).toInt(),
      kind: $enumDecode(
        _$NotificationKindEnumMap,
        json['type'],
        unknownValue: NotificationKind.unknown,
      ),
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['isRead'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      reservationId: (json['reservationId'] as num?)?.toInt(),
      readAt: json['readAt'] == null
          ? null
          : DateTime.parse(json['readAt'] as String),
    );

const _$NotificationKindEnumMap = {
  NotificationKind.reservationCreated: 'ReservationCreated',
  NotificationKind.reservationStatusChanged: 'ReservationStatusChanged',
  NotificationKind.paymentSucceeded: 'PaymentSucceeded',
  NotificationKind.refundProcessed: 'RefundProcessed',
  NotificationKind.hostVerificationDecided: 'HostVerificationDecided',
  NotificationKind.unknown: 'unknown',
};
