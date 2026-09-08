import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

@immutable
sealed class ChatEvent {
  const ChatEvent();
}

final class ChatJoined extends ChatEvent {
  const ChatJoined();
}

final class ChatDropped extends ChatEvent {
  const ChatDropped();
}

final class ChatSaid extends ChatEvent {
  const ChatSaid(this.message);

  final Message message;
}

// Where a line arrives from while the thread it belongs to is being read.
//
// A phone reads one thread at a time, so this carries one: opening another
// gives up the first, and the socket lives exactly as long as somebody is
// listening to it. That is what lets the screen drop it when the application
// goes behind the reader and take it again when it comes back.
abstract interface class ChatHub {
  // Mounted beside the API rather than under it.
  static const String path = '/hubs/chat';

  // Connected on the first listen, given up when the listen is cancelled.
  Stream<ChatEvent> watch(int conversationId);

  // The id of a thread this account is in that has just been spoken in, for the
  // tab badge and the inbox, which are not inside one. Held on its own socket
  // and given up the same way.
  Stream<int> watchAccount();

  Future<void> close();
}
