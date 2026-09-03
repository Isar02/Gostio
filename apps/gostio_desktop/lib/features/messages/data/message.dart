import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

@JsonSerializable(createToJson: false)
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.senderName,
    required this.body,
    required this.sentAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);

  final int id;
  final int conversationId;
  final int senderUserId;
  final String senderName;
  final String body;
  final DateTime sentAt;
}
