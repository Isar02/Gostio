import '../../../core/network/api_client.dart';
import 'message.dart';

// The one call the hub makes carries the message as its only argument.
abstract final class ChatBroadcast {
  static Message? read(List<Object?>? arguments) {
    final Object? payload = arguments == null || arguments.isEmpty
        ? null
        : arguments.first;

    if (payload is! JsonMap) {
      return null;
    }

    try {
      return Message.fromJson(payload);
    } on Object {
      return null;
    }
  }
}
