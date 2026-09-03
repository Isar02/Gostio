import 'dart:async';

import 'package:gostio_desktop/features/messages/data/chat_connection.dart';
import 'package:gostio_desktop/features/messages/data/chat_hub.dart';

// A hub whose events a test hands out itself, so what a thread does about
// being carried, being dropped and being told is exercised without a socket.
class ChatHubDouble implements ChatHub {
  final Map<int, StreamController<ChatEvent>> watching =
      <int, StreamController<ChatEvent>>{};

  final List<int> watched = <int>[];
  final List<int> given = <int>[];

  bool get isClosed => _isClosed;

  bool _isClosed = false;

  // Closed by close(), which every test that reaches for one runs on the way
  // out; a stream left open here would outlive the thread that listened to it.
  @override
  Stream<ChatEvent> watch(int conversationId) {
    watched.add(conversationId);

    watching[conversationId] = StreamController<ChatEvent>(
      onCancel: () => given.add(conversationId),
    );

    return watching[conversationId]!.stream;
  }

  // A stream hands its listener the event on a microtask, so the caller waits
  // for one rather than for a timer: the clock is not running in a widget test
  // until it is pumped.
  Future<void> say(int conversationId, ChatEvent event) async {
    watching[conversationId]?.add(event);

    await Future<void>.microtask(() {});
  }

  @override
  Future<void> close() async {
    _isClosed = true;

    for (final StreamController<ChatEvent> events in watching.values) {
      await events.close();
    }
    watching.clear();
  }
}

// A connection whose start a test finishes itself, so the moments between
// asking for a socket and standing one up can be held open.
class ChatConnectionDouble implements ChatConnection {
  ChatConnectionDouble({required this.isHeld});

  final bool isHeld;
  final Completer<void> starting = Completer<void>();

  // Every group call, in the order it was made, as `Join 7`.
  final List<String> calls = <String>[];

  bool isStarted = false;
  bool isStopped = false;

  void Function(List<Object?>? arguments)? said;
  void Function(Object? failure)? lost;
  void Function()? restored;

  @override
  bool get isConnected => isStarted && !isStopped;

  @override
  void listen({
    required void Function(List<Object?>? arguments) said,
    required void Function(Object? failure) lost,
    required void Function() restored,
  }) {
    this.said = said;
    this.lost = lost;
    this.restored = restored;
  }

  @override
  Future<void> start() async {
    if (isHeld) {
      await starting.future;
    }

    isStarted = true;
  }

  // A real connection closes on the way out, which is what tells the hub it
  // went. A double that only sets a flag hides whatever that closing reaches.
  @override
  Future<void> stop() async {
    isStopped = true;
    lost?.call(StateError('the connection was stopped'));
  }

  @override
  Future<void> invoke(String method, List<Object> arguments) async {
    if (!isConnected) {
      throw StateError('This connection is not up.');
    }

    calls.add('$method ${arguments.first}');
  }
}

class ChatConnectionsDouble {
  ChatConnectionsDouble({this.isHeld = false});

  final bool isHeld;
  final List<ChatConnectionDouble> opened = <ChatConnectionDouble>[];

  ChatConnectionDouble get only => opened.single;

  ChatConnection open() {
    final ChatConnectionDouble connection = ChatConnectionDouble(
      isHeld: isHeld,
    );
    opened.add(connection);

    return connection;
  }
}
