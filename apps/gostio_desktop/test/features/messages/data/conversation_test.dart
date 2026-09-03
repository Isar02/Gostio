import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/messages/data/conversation.dart';
import 'package:gostio_desktop/features/messages/data/conversation_participant.dart';
import 'package:gostio_desktop/features/messages/data/conversation_type.dart';
import 'package:gostio_desktop/features/messages/data/message.dart';

import '../../../support/conversation_fixture.dart';

void main() {
  test('a thread is named by everybody in it but the reader', () {
    expect(conversation().withWhom(administratorId), 'Maja Popović');
    expect(conversation().joinedBy(administratorId), isTrue);
  });

  // A support thread an administrator has answered holds two other people, and
  // the one it is about is whoever wrote to support.
  test('the thread is named by whoever opened it first', () {
    final Conversation answered = conversation(
      participants: <ConversationParticipant>[
        participant(
          userId: 3,
          username: 'administrator',
          name: 'Nedim Alispahić',
        ),
        participant(),
      ],
    );

    expect(answered.withWhom(1), 'Maja Popović, Nedim Alispahić');
    expect(answered.othersThan(1).first.userId, guestId);
  });

  // An administrator reaches every support thread and is in none of them until
  // they answer one, which is a thread with one name in it rather than none.
  test('a thread the reader has not answered still names who asked', () {
    final Conversation waiting = conversation(
      participants: <ConversationParticipant>[participant()],
    );

    expect(waiting.joinedBy(administratorId), isFalse);
    expect(waiting.withWhom(administratorId), 'Maja Popović');
  });

  test('a thread holding nobody else says so rather than drawing a blank', () {
    final Conversation alone = conversation(
      participants: <ConversationParticipant>[
        participant(userId: administratorId, name: 'Dina Kovačević'),
      ],
    );

    expect(alone.withWhom(administratorId), 'Nobody else');
  });

  test('a message is read once somebody else has read as far as it', () {
    final Message answered = message(
      id: 2,
      senderUserId: administratorId,
      senderName: 'Dina Kovačević',
      sentAt: DateTime.utc(2026, 8, 28, 10),
    );

    expect(
      conversation(
        participants: <ConversationParticipant>[
          participant(lastReadAt: DateTime.utc(2026, 8, 28, 10)),
          participant(userId: administratorId, name: 'Dina Kovačević'),
        ],
      ).wasReadByAnother(answered),
      isTrue,
    );

    expect(
      conversation(
        participants: <ConversationParticipant>[
          participant(lastReadAt: DateTime.utc(2026, 8, 28, 9, 30)),
          participant(userId: administratorId, name: 'Dina Kovačević'),
        ],
      ).wasReadByAnother(answered),
      isFalse,
    );
  });

  // The reader's own timestamp says nothing about whether it reached anybody.
  test('reading a thread does not mark what the reader wrote as read', () {
    final Message mine = message(
      id: 2,
      senderUserId: administratorId,
      sentAt: DateTime.utc(2026, 8, 28, 10),
    );

    expect(
      conversation(
        participants: <ConversationParticipant>[
          participant(),
          participant(
            userId: administratorId,
            name: 'Dina Kovačević',
            lastReadAt: DateTime.utc(2026, 8, 28, 11),
          ),
        ],
      ).wasReadByAnother(mine),
      isFalse,
    );
  });

  test('a kind this build does not know is still a thread', () {
    final Conversation read = Conversation.fromJson(<String, dynamic>{
      'id': 7,
      'type': 'Broadcast',
      'openedByUserId': 21,
      'participants': <dynamic>[],
      'unreadCount': 0,
      'createdAt': '2026-08-28T09:00:00Z',
      'lastActivityAt': '2026-08-28T09:00:00Z',
    });

    expect(read.type, ConversationType.unknown);
    expect(read.holdsUnread, isFalse);
  });
}
