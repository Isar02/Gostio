import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/messages/data/chat_broadcast.dart';
import 'package:gostio_desktop/features/messages/data/message.dart';

void main() {
  test('the hub carries the message as the one argument of its call', () {
    final Message? said = ChatBroadcast.read(<Object?>[
      <String, dynamic>{
        'id': 44,
        'conversationId': 7,
        'senderUserId': 21,
        'senderName': 'Maja Popović',
        'body': 'It arrived this morning, thank you.',
        'sentAt': '2026-08-28T09:12:00Z',
      },
    ]);

    expect(said?.id, 44);
    expect(said?.conversationId, 7);
    expect(said?.body, 'It arrived this morning, thank you.');
    expect(said?.sentAt.isUtc, isTrue);
  });

  // A broadcast this build cannot read leaves the thread as it was, reading
  // and sending through the API the way it does when the hub is not there.
  test('a call carrying nothing this build can read is ignored', () {
    expect(ChatBroadcast.read(null), isNull);
    expect(ChatBroadcast.read(<Object?>[]), isNull);
    expect(ChatBroadcast.read(<Object?>['MessageSent']), isNull);
    expect(
      ChatBroadcast.read(<Object?>[
        <String, dynamic>{'id': 44, 'body': 'Half a message.'},
      ]),
      isNull,
    );
  });
}
