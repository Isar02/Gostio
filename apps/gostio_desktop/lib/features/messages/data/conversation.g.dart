// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Conversation _$ConversationFromJson(Map<String, dynamic> json) => Conversation(
  id: (json['id'] as num).toInt(),
  type: $enumDecode(
    _$ConversationTypeEnumMap,
    json['type'],
    unknownValue: ConversationType.unknown,
  ),
  openedByUserId: (json['openedByUserId'] as num).toInt(),
  participants: (json['participants'] as List<dynamic>)
      .map((e) => ConversationParticipant.fromJson(e as Map<String, dynamic>))
      .toList(),
  unreadCount: (json['unreadCount'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  lastActivityAt: DateTime.parse(json['lastActivityAt'] as String),
  reservationId: (json['reservationId'] as num?)?.toInt(),
  listingTitle: json['listingTitle'] as String?,
  lastMessage: json['lastMessage'] == null
      ? null
      : Message.fromJson(json['lastMessage'] as Map<String, dynamic>),
);

const _$ConversationTypeEnumMap = {
  ConversationType.direct: 'Direct',
  ConversationType.support: 'Support',
  ConversationType.unknown: 'unknown',
};
