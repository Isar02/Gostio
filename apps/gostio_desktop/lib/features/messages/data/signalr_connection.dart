import 'dart:async';

import 'package:signalr_netcore/signalr_client.dart';

import 'chat_connection.dart';

class SignalRConnection implements ChatConnection {
  SignalRConnection({required String address, required String? Function() token})
    : _connection = HubConnectionBuilder()
          .withUrl(
            address,
            options: HttpConnectionOptions(
              // A socket handshake carries no headers, so the token goes in the
              // query string, which is the one path the API reads it from.
              accessTokenFactory: () async => token() ?? '',
            ),
          )
          .withAutomaticReconnect()
          .build();

  static const String messageSent = 'MessageSent';

  final HubConnection _connection;

  @override
  bool get isConnected => _connection.state == HubConnectionState.Connected;

  @override
  void listen({
    required void Function(List<Object?>? arguments) said,
    required void Function(Object? failure) lost,
    required void Function() restored,
  }) {
    _connection
      ..on(messageSent, said)
      ..onclose(({Exception? error}) => lost(error))
      ..onreconnecting(({Exception? error}) => lost(error))
      ..onreconnected(({String? connectionId}) => restored());
  }

  @override
  Future<void> start() => _connection.start() ?? Future<void>.value();

  @override
  Future<void> stop() => _connection.stop();

  @override
  Future<void> invoke(String method, List<Object> arguments) =>
      _connection.invoke(method, args: arguments);
}
