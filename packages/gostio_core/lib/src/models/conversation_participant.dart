import 'package:json_annotation/json_annotation.dart';

part 'conversation_participant.g.dart';

@JsonSerializable(createToJson: false)
class ConversationParticipant {
  const ConversationParticipant({
    required this.userId,
    required this.username,
    required this.name,
    required this.hasProfileImage,
    required this.joinedAt,
    this.lastReadAt,
  });

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) =>
      _$ConversationParticipantFromJson(json);

  final int userId;
  final String username;
  final String name;

  // Whether there is a picture to fetch: no reply carries the bytes.
  final bool hasProfileImage;

  final DateTime joinedAt;

  final DateTime? lastReadAt;

  bool hasRead(DateTime moment) {
    final DateTime? read = lastReadAt;

    return read != null && !read.isBefore(moment);
  }
}
