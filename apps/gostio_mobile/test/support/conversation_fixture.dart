import 'package:gostio_core/gostio_core.dart';

// The reader every thread in the suite is drawn for, and the host on the other
// side of it. Named here so a test says which side a line is on rather than
// repeating two numbers.
const int reader = 12;
const int host = 31;

ConversationParticipant party({
  int userId = reader,
  String username = 'emina.b',
  String name = 'Emina Begić',
  DateTime? lastReadAt,
}) => ConversationParticipant(
  userId: userId,
  username: username,
  name: name,
  hasProfileImage: false,
  joinedAt: DateTime.utc(2026, 8, 30, 9),
  lastReadAt: lastReadAt,
);

Message line({
  int id = 1,
  int conversationId = 7,
  int senderUserId = host,
  String senderName = 'Lejla Begić',
  String body = 'There is room for two cars inside the gate.',
  DateTime? sentAt,
}) => Message(
  id: id,
  conversationId: conversationId,
  senderUserId: senderUserId,
  senderName: senderName,
  body: body,
  sentAt: sentAt ?? DateTime.utc(2026, 9, 5, 10, 30),
);

// A thread the way the API answers one. What a test is about it names itself;
// everything else is a plausible row from the seed.
Conversation thread({
  int id = 7,
  ConversationType type = ConversationType.direct,
  int openedByUserId = reader,
  int? reservationId = 314,
  String? listingTitle = 'Apartment above the Neretva in Konjic',
  List<ConversationParticipant>? participants,
  Message? lastMessage,
  int unreadCount = 0,
  DateTime? lastActivityAt,
}) => Conversation(
  id: id,
  type: type,
  openedByUserId: openedByUserId,
  reservationId: reservationId,
  listingTitle: listingTitle,
  participants:
      participants ??
      <ConversationParticipant>[
        party(),
        party(userId: host, username: 'lejla.b', name: 'Lejla Begić'),
      ],
  lastMessage: lastMessage ?? line(conversationId: id),
  unreadCount: unreadCount,
  createdAt: DateTime.utc(2026, 8, 30, 9),
  lastActivityAt: lastActivityAt ?? DateTime.utc(2026, 9, 5, 10, 30),
);

List<Conversation> threads(int count) => <Conversation>[
  for (int index = 1; index <= count; index++)
    thread(
      id: index,
      listingTitle: 'Listing $index',
      lastMessage: line(id: index, conversationId: index, body: 'Line $index'),
    ),
];
