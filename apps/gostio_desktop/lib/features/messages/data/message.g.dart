// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Message _$MessageFromJson(Map<String, dynamic> json) => Message(
  id: (json['id'] as num).toInt(),
  conversationId: (json['conversationId'] as num).toInt(),
  senderUserId: (json['senderUserId'] as num).toInt(),
  senderName: json['senderName'] as String,
  body: json['body'] as String,
  sentAt: DateTime.parse(json['sentAt'] as String),
);
