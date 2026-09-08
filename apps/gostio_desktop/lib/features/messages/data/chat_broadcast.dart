import 'package:gostio_core/gostio_core.dart';

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

  // The nudge carries the thread it is about and nothing else.
  static int? touched(List<Object?>? arguments) =>
      arguments == null || arguments.isEmpty ? null : arguments.first as int?;
}
