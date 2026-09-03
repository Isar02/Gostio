import 'package:json_annotation/json_annotation.dart';

import 'conversation_participant.dart';
import 'conversation_type.dart';
import 'message.dart';

part 'conversation.g.dart';

@JsonSerializable(createToJson: false)
class Conversation {
  const Conversation({
    required this.id,
    required this.type,
    required this.openedByUserId,
    required this.participants,
    required this.unreadCount,
    required this.createdAt,
    required this.lastActivityAt,
    this.reservationId,
    this.listingTitle,
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) =>
      _$ConversationFromJson(json);

  final int id;

  @JsonKey(unknownEnumValue: ConversationType.unknown)
  final ConversationType type;

  final int openedByUserId;

  final List<ConversationParticipant> participants;
  final int unreadCount;
  final DateTime createdAt;

  final DateTime lastActivityAt;

  final int? reservationId;
  final String? listingTitle;
  final Message? lastMessage;

  bool get holdsUnread => unreadCount > 0;

  bool get isAboutABooking => reservationId != null;

  bool joinedBy(int callerId) =>
      participants.any((ConversationParticipant one) => one.userId == callerId);

  // Everybody but the reader, with whoever opened the thread first: a queue is
  // read by who is waiting in it.
  List<ConversationParticipant> othersThan(int callerId) {
    final List<ConversationParticipant> asked = <ConversationParticipant>[];
    final List<ConversationParticipant> rest = <ConversationParticipant>[];

    for (final ConversationParticipant one in participants) {
      if (one.userId == callerId) {
        continue;
      }

      (one.userId == openedByUserId ? asked : rest).add(one);
    }

    return <ConversationParticipant>[...asked, ...rest];
  }

  String withWhom(int callerId) {
    final List<ConversationParticipant> others = othersThan(callerId);

    return others.isEmpty
        ? 'Nobody else'
        : others.map((ConversationParticipant one) => one.name).join(', ');
  }

  bool wasReadByAnother(Message message) => participants.any(
    (ConversationParticipant one) =>
        one.userId != message.senderUserId && one.hasRead(message.sentAt),
  );
}
