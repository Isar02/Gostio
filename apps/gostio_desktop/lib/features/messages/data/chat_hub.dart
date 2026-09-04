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
  const ChatDropped(this.reason);

  final String reason;
}

final class ChatSaid extends ChatEvent {
  const ChatSaid(this.message);

  final Message message;
}

abstract interface class ChatHub {
  // Mounted beside the API rather than under it.
  static const String path = '/hubs/chat';

  // Connected on the first listen, given up when the last is cancelled.
  Stream<ChatEvent> watch(int conversationId);

  Future<void> close();
}
