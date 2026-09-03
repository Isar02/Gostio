import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/messages/data/conversation_query.dart';
import 'package:gostio_desktop/features/messages/data/conversation_type.dart';

void main() {
  test('a filter nobody set sends nothing', () {
    expect(const ConversationQuery().toParameters(), isEmpty);
    expect(const ConversationQuery().isEmpty, isTrue);
  });

  test('a kind goes out by the name the API binds', () {
    expect(
      const ConversationQuery(type: ConversationType.support).toParameters(),
      <String, dynamic>{'type': 'Support'},
    );
  });

  // The inbox narrowed to the account's own threads is not a filter the reader
  // set, so it does not make the empty state say nothing matches.
  test('the account whose threads these are narrows without filtering', () {
    const ConversationQuery query = ConversationQuery(joinedBy: 1);

    expect(query.toParameters(), <String, dynamic>{'withUserId': 1});
    expect(query.isEmpty, isTrue);
  });

  test('changing the kind keeps whose threads are being read', () {
    const ConversationQuery query = ConversationQuery(joinedBy: 1);

    expect(
      query.withType(ConversationType.direct),
      const ConversationQuery(type: ConversationType.direct, joinedBy: 1),
    );
  });
}
