import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_client.dart';
import 'package:gostio_desktop/features/messages/data/chat_hub.dart';
import 'package:gostio_desktop/features/messages/data/signalr_chat_hub.dart';

import '../../../support/chat_doubles.dart';

void main() {
  test('nothing opens a socket until a thread listens', () async {
    final ChatConnectionsDouble connections = ChatConnectionsDouble();
    _hub(connections);

    await pumpEventQueue();

    expect(connections.opened, isEmpty);
  });

  test('two threads open at once share one connection', () async {
    final ChatConnectionsDouble connections = ChatConnectionsDouble();
    final ChatHub hub = _hub(connections);

    final StreamSubscription<ChatEvent> first = hub.watch(7).listen(_nothing);
    final StreamSubscription<ChatEvent> second = hub.watch(9).listen(_nothing);
    await pumpEventQueue();

    expect(connections.opened, hasLength(1));
    expect(connections.only.calls, <String>['Join 7', 'Join 9']);

    await first.cancel();

    expect(connections.only.calls.last, 'Leave 7');
    expect(connections.only.isStopped, isFalse);

    await second.cancel();

    expect(connections.only.isStopped, isTrue);
  });

  // The socket takes as long as it takes, and a reader who moves on before it
  // stands up leaves nothing behind them.
  test(
    'a thread left while the hub connects takes the socket with it',
    () async {
      final ChatConnectionsDouble connections = ChatConnectionsDouble(
        isHeld: true,
      );
      final ChatHub hub = _hub(connections);

      final StreamSubscription<ChatEvent> listening = hub
          .watch(7)
          .listen(_nothing);
      await pumpEventQueue();

      await listening.cancel();

      connections.only.starting.complete();
      await pumpEventQueue();

      expect(connections.only.isStopped, isTrue);
      expect(connections.only.calls, isEmpty);
    },
  );

  // The connection that was given up is not the one the next thread waits on,
  // and clearing up after it is not allowed to take the new one with it.
  test('a thread opened after that gets one socket rather than two', () async {
    final ChatConnectionsDouble connections = ChatConnectionsDouble(
      isHeld: true,
    );
    final ChatHub hub = _hub(connections);

    final StreamSubscription<ChatEvent> left = hub.watch(7).listen(_nothing);
    await pumpEventQueue();
    await left.cancel();

    final StreamSubscription<ChatEvent> opened = hub.watch(9).listen(_nothing);
    await pumpEventQueue();

    expect(connections.opened, hasLength(2));

    for (final ChatConnectionDouble connection in connections.opened) {
      connection.starting.complete();
    }
    await pumpEventQueue();

    expect(connections.opened.first.isStopped, isTrue);
    expect(connections.opened.first.calls, isEmpty);
    expect(connections.opened.last.isStopped, isFalse);
    expect(connections.opened.last.calls, <String>['Join 9']);

    await opened.cancel();
  });

  // The same thread again, with the new connection standing up first: what the
  // one before it gave up is not news for the watcher that replaced it.
  test('a thread reopened while the first was connecting stays live', () async {
    final ChatConnectionsDouble connections = ChatConnectionsDouble(
      isHeld: true,
    );
    final ChatHub hub = _hub(connections);

    final StreamSubscription<ChatEvent> left = hub.watch(7).listen(_nothing);
    await pumpEventQueue();
    await left.cancel();

    final List<ChatEvent> heard = <ChatEvent>[];
    final StreamSubscription<ChatEvent> opened = hub.watch(7).listen(heard.add);
    await pumpEventQueue();

    expect(connections.opened, hasLength(2));

    connections.opened.last.starting.complete();
    await pumpEventQueue();
    connections.opened.first.starting.complete();
    await pumpEventQueue();

    expect(heard.whereType<ChatJoined>(), hasLength(1));
    expect(heard.whereType<ChatDropped>(), isEmpty);
    expect(connections.opened.last.isStopped, isFalse);
    expect(connections.opened.last.calls, <String>['Join 7']);

    await opened.cancel();
  });

  test('a thread hears that the connection went, and why', () async {
    final ChatConnectionsDouble connections = ChatConnectionsDouble();
    final ChatHub hub = _hub(connections);

    final List<ChatEvent> heard = <ChatEvent>[];
    final StreamSubscription<ChatEvent> listening = hub
        .watch(7)
        .listen(heard.add);
    await pumpEventQueue();

    connections.only.lost!(StateError('the socket closed'));
    await pumpEventQueue();

    expect(heard.first, isA<ChatJoined>());
    expect((heard.last as ChatDropped).reason, contains('the socket closed'));

    await listening.cancel();
  });

  // The groups died with the connection that held them.
  test('a connection that came back is joined to every open thread', () async {
    final ChatConnectionsDouble connections = ChatConnectionsDouble();
    final ChatHub hub = _hub(connections);

    final StreamSubscription<ChatEvent> listening = hub
        .watch(7)
        .listen(_nothing);
    await pumpEventQueue();

    connections.only.restored!();
    await pumpEventQueue();

    expect(connections.only.calls, <String>['Join 7', 'Join 7']);

    await listening.cancel();
  });

  test('a broadcast reaches the thread it names', () async {
    final ChatConnectionsDouble connections = ChatConnectionsDouble();
    final ChatHub hub = _hub(connections);

    final List<ChatEvent> heard = <ChatEvent>[];
    final StreamSubscription<ChatEvent> listening = hub
        .watch(7)
        .listen(heard.add);
    await pumpEventQueue();

    connections.only.said!(<Object?>[
      <String, dynamic>{
        'id': 44,
        'conversationId': 7,
        'senderUserId': 21,
        'senderName': 'Maja Popović',
        'body': 'It arrived this morning, thank you.',
        'sentAt': '2026-08-28T09:12:00Z',
      },
    ]);
    await pumpEventQueue();

    expect(heard.whereType<ChatSaid>().single.message.id, 44);

    await listening.cancel();
  });

  test('closing the hub stops the socket and the threads on it', () async {
    final ChatConnectionsDouble connections = ChatConnectionsDouble();
    final ChatHub hub = _hub(connections);

    var isDone = false;
    hub.watch(7).listen(_nothing, onDone: () => isDone = true);
    await pumpEventQueue();

    await hub.close();
    await pumpEventQueue();

    expect(connections.only.isStopped, isTrue);
    expect(isDone, isTrue);
  });
}

void _nothing(ChatEvent event) {}

ChatHub _hub(ChatConnectionsDouble connections) {
  final SignalRChatHub hub = SignalRChatHub(
    ApiClient(baseUrl: Uri.parse('http://localhost:5000')),
    baseUrl: Uri.parse('http://localhost:5000'),
    open: connections.open,
  );
  addTearDown(hub.close);

  return hub;
}
