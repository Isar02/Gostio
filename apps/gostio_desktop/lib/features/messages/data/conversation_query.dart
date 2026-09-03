import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import 'conversation_type.dart';

// A filter nobody set is left out of the request rather than sent empty,
// which the API would read as a value to match.
@immutable
class ConversationQuery {
  const ConversationQuery({this.type, this.joinedBy});

  final ConversationType? type;

  // An administrator reaches every support thread, so naming themselves is
  // what narrows the inbox to their own. For anybody else it narrows nothing.
  final int? joinedBy;

  bool get isEmpty => type == null;

  JsonMap toParameters() => <String, dynamic>{
    'type': ?type?.wireName,
    'withUserId': ?joinedBy,
  };

  ConversationQuery withType(ConversationType? type) =>
      ConversationQuery(type: type, joinedBy: joinedBy);

  @override
  bool operator ==(Object other) =>
      other is ConversationQuery &&
      other.type == type &&
      other.joinedBy == joinedBy;

  @override
  int get hashCode => Object.hash(type, joinedBy);
}
