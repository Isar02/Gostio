import 'package:gostio_core/gostio_core.dart';

// The one call the hub makes carries the message as its only argument. A call
// this build cannot read is not a line, and it is dropped rather than allowed
// to take a thread down with it.
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
