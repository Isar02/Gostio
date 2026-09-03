// The part of a hub connection the client uses, with the socket behind it.
abstract interface class ChatConnection {
  bool get isConnected;

  Future<void> start();

  Future<void> stop();

  Future<void> invoke(String method, List<Object> arguments);

  // Called once, before the connection is started.
  void listen({
    required void Function(List<Object?>? arguments) said,
    required void Function(Object? failure) lost,
    required void Function() restored,
  });
}

typedef ChatConnections = ChatConnection Function();
