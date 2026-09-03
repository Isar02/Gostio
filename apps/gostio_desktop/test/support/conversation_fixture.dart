import 'package:gostio_desktop/features/messages/data/conversation.dart';
import 'package:gostio_desktop/features/messages/data/conversation_participant.dart';
import 'package:gostio_desktop/features/messages/data/conversation_type.dart';
import 'package:gostio_desktop/features/messages/data/message.dart';

// The account the desktop tests sign in as, and the guest on the other side of
// most of these threads.
const int administratorId = 1;
const int guestId = 21;

ConversationParticipant participant({
  int userId = guestId,
  String username = 'maja.popovic',
  String name = 'Maja Popović',
  bool hasProfileImage = false,
  DateTime? lastReadAt,
}) => ConversationParticipant(
  userId: userId,
  username: username,
  name: name,
  hasProfileImage: hasProfileImage,
  joinedAt: DateTime.utc(2026, 8, 28, 9),
  lastReadAt: lastReadAt,
);

Message message({
  int id = 1,
  int conversationId = 7,
  int senderUserId = guestId,
  String senderName = 'Maja Popović',
  String body =
      'My refund is showing as processed but the money is not on my '
      'card yet.',
  DateTime? sentAt,
}) => Message(
  id: id,
  conversationId: conversationId,
  senderUserId: senderUserId,
  senderName: senderName,
  body: body,
  sentAt: sentAt ?? DateTime.utc(2026, 8, 28, 9, 5),
);

Conversation conversation({
  int id = 7,
  ConversationType type = ConversationType.support,
  List<ConversationParticipant>? participants,
  int openedByUserId = guestId,
  int unreadCount = 1,
  int? reservationId,
  String? listingTitle,
  Message? lastMessage,
  DateTime? lastActivityAt,
}) => Conversation(
  id: id,
  type: type,
  participants:
      participants ??
      <ConversationParticipant>[
        participant(),
        participant(
          userId: administratorId,
          username: 'desktop',
          name: 'Dina Kovačević',
        ),
      ],
  openedByUserId: openedByUserId,
  unreadCount: unreadCount,
  createdAt: DateTime.utc(2026, 8, 28, 9),
  lastActivityAt: lastActivityAt ?? DateTime.utc(2026, 8, 28, 9, 5),
  reservationId: reservationId,
  listingTitle: listingTitle,
  lastMessage: lastMessage ?? message(conversationId: id),
);
