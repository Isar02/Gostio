import 'dart:async';

import 'package:gostio_mobile/core/push/push_messaging.dart';
import 'package:gostio_mobile/core/push/push_notice.dart';

// A delivery service with no service behind it. A test hands it a token, then
// rotates one, delivers one and has one tapped, which is the whole of what the
// client is written against.
class PushMessagingDouble implements PushMessaging {
  PushMessagingDouble({this.token, this.tokenFailure});

  final String? token;
  final Object? tokenFailure;

  final StreamController<String> tokens = StreamController<String>.broadcast();
  final StreamController<PushNotice> arriving =
      StreamController<PushNotice>.broadcast();
  final StreamController<PushNotice> taps =
      StreamController<PushNotice>.broadcast();

  int tokenCalls = 0;
  int askCalls = 0;
  bool isClosed = false;

  @override
  Future<String?> deviceToken() async {
    tokenCalls++;

    if (tokenFailure != null) {
      return null;
    }

    return token;
  }

  @override
  Stream<String> get deviceTokenChanges => tokens.stream;

  @override
  Stream<PushNotice> get arrivals => arriving.stream;

  @override
  Stream<PushNotice> get opened => taps.stream;

  @override
  Future<void> askToDrawNotices() async {
    askCalls++;
  }

  @override
  Future<void> close() async {
    isClosed = true;
    await tokens.close();
    await arriving.close();
    await taps.close();
  }
}
