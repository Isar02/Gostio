import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/messages/data/chat_connection.dart';
import 'package:gostio_mobile/features/messages/data/chat_hub.dart';
import 'package:gostio_mobile/features/messages/data/signalr_chat_hub.dart';

import '../../../support/conversation_fixture.dart';

// The hub over a connection with no socket under it, so what it does with a
// join, a delivery and a connection that comes and goes can be read.
class ConnectionDouble implements ChatConnection {
  ConnectionDouble({this.refusesToStart = false});

  final bool refusesToStart;

  bool started = false;
  int stops = 0;
  final List<List<Object>> invoked = <List<Object>>[];

  void Function(List<Object?>? arguments)? _said;
  void Function(Object? failure)? _lost;
  void Function()? _restored;

  void deliver(JsonMap message) => _said?.call(<Object?>[message]);

  void drop(Object? failure) => _lost?.call(failure);

  void restore() => _restored?.call();

  @override
  bool get isConnected => started;

  @override
  void listen({
    required void Function(List<Object?>? arguments) said,
    required void Function(Object? failure) lost,
    required void Function() restored,
  }) {
    _said = said;
    _lost = lost;
    _restored = restored;
  }

  @override
  Future<void> start() async {
    if (refusesToStart) {
      throw StateError('The hub could not be reached.');
    }

    started = true;
  }

  @override
  Future<void> stop() async {
    started = false;
    stops++;
  }

  @override
  Future<void> invoke(String method, List<Object> arguments) async =>
      invoked.add(<Object>[method, ...arguments]);
}

JsonMap sent({int id = 90, int conversationId = 7, String body = 'Hello.'}) =>
    <String, dynamic>{
      'id': id,
      'conversationId': conversationId,
      'senderUserId': host,
      'senderName': 'Lejla Begić',
      'body': body,
      'sentAt': '2026-09-05T10:30:00Z',
    };

void main() {
  ({SignalRChatHub hub, ConnectionDouble connection}) hubOver({
    bool refusesToStart = false,
  }) {
    final ConnectionDouble connection = ConnectionDouble(
      refusesToStart: refusesToStart,
    );

    return (
      hub: SignalRChatHub(
        ApiClient(baseUrl: Uri.parse('http://10.0.2.2:5000')),
        baseUrl: Uri.parse('http://10.0.2.2:5000'),
        open: () => connection,
      ),
      connection: connection,
    );
  }

  test('listening to a thread joins it and says so', () async {
    final ({SignalRChatHub hub, ConnectionDouble connection}) over = hubOver();
    final List<ChatEvent> heard = <ChatEvent>[];

    over.hub.watch(7).listen(heard.add);
    await pumpEventQueue();

    expect(over.connection.invoked, <List<Object>>[
      <Object>['Join', 7],
    ]);
    expect(heard.single, isA<ChatJoined>());

    await over.hub.close();
  });

  test('a line for this thread is delivered and another one is not', () async {
    final ({SignalRChatHub hub, ConnectionDouble connection}) over = hubOver();
    final List<ChatEvent> heard = <ChatEvent>[];

    over.hub.watch(7).listen(heard.add);
    await pumpEventQueue();

    over.connection
      ..deliver(sent(body: 'For this thread.'))
      ..deliver(sent(id: 91, conversationId: 8, body: 'For another.'));
    await pumpEventQueue();

    expect(
      heard.whereType<ChatSaid>().map((ChatSaid said) => said.message.body),
      <String>['For this thread.'],
    );

    await over.hub.close();
  });

  // The group the connection was in did not come back with it, so the thread
  // is joined again before anything can be delivered to it.
  test('a connection that comes back joins the thread again', () async {
    final ({SignalRChatHub hub, ConnectionDouble connection}) over = hubOver();
    final List<ChatEvent> heard = <ChatEvent>[];

    over.hub.watch(7).listen(heard.add);
    await pumpEventQueue();

    over.connection.drop(null);
    await pumpEventQueue();
    over.connection.restore();
    await pumpEventQueue();

    expect(over.connection.invoked.length, 2);
    expect(
      heard.map((ChatEvent event) => event.runtimeType.toString()),
      <String>['ChatJoined', 'ChatDropped', 'ChatJoined'],
    );

    await over.hub.close();
  });

  test(
    'a connection that could not be made is reported rather than thrown',
    () async {
      final ({SignalRChatHub hub, ConnectionDouble connection}) over = hubOver(
        refusesToStart: true,
      );
      final List<ChatEvent> heard = <ChatEvent>[];

      over.hub.watch(7).listen(heard.add);
      await pumpEventQueue();

      expect(heard.single, isA<ChatDropped>());

      await over.hub.close();
    },
  );

  // A phone in a pocket holds nothing open.
  test('cancelling the listen gives up the socket', () async {
    final ({SignalRChatHub hub, ConnectionDouble connection}) over = hubOver();

    final StreamSubscription<ChatEvent> listening = over.hub
        .watch(7)
        .listen((ChatEvent _) {});
    await pumpEventQueue();

    await listening.cancel();
    await pumpEventQueue();

    expect(over.connection.stops, 1);

    await over.hub.close();
  });

  // A phone reads one thread at a time, so a second replaces the first rather
  // than leaving two sockets open on one screen's worth of reading.
  test('a second thread replaces the first', () async {
    final List<ConnectionDouble> made = <ConnectionDouble>[];
    final SignalRChatHub hub = SignalRChatHub(
      ApiClient(baseUrl: Uri.parse('http://10.0.2.2:5000')),
      baseUrl: Uri.parse('http://10.0.2.2:5000'),
      open: () {
        final ConnectionDouble connection = ConnectionDouble();
        made.add(connection);

        return connection;
      },
    );

    final List<ChatEvent> first = <ChatEvent>[];
    hub.watch(7).listen(first.add);
    await pumpEventQueue();

    hub.watch(8).listen((ChatEvent _) {});
    await pumpEventQueue();

    expect(made.length, 2);
    expect(made.first.stops, 1);
    expect(made.last.invoked, <List<Object>>[
      <Object>['Join', 8],
    ]);

    // The first thread hears nothing more: what it was watching is gone.
    made.first.deliver(sent());
    await pumpEventQueue();

    expect(first.whereType<ChatSaid>(), isEmpty);

    await hub.close();
  });
}
