// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_participant.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConversationParticipant _$ConversationParticipantFromJson(
  Map<String, dynamic> json,
) => ConversationParticipant(
  userId: (json['userId'] as num).toInt(),
  username: json['username'] as String,
  name: json['name'] as String,
  hasProfileImage: json['hasProfileImage'] as bool,
  joinedAt: DateTime.parse(json['joinedAt'] as String),
  lastReadAt: json['lastReadAt'] == null
      ? null
      : DateTime.parse(json['lastReadAt'] as String),
);
