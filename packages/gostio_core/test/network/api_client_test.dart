import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

const String _poll = '/notifications';
const String _change = '/auth/change-password';

// When a 401 means the session is over and when it means something narrower.
void main() {
  test('a refusal of the token in force ends the session', () async {
    final _Server server = _Server()..answer();
    final ApiClient client = _signedIn(server);

    await expectLater(client.get(_poll), throwsA(isA<ApiException>()));

    expect(server.endedTheSession, isTrue);
  });

  // A late answer to a call made before the current sign in. The token has to
  // move after the request carried the old one, which is why the answer is
  // held until it has: dio stamps the header asynchronously, so a token
  // changed in the next line is the one that goes out.
  test('a refusal of a token no longer held ends nothing', () async {
    final _Server server = _Server();
    final ApiClient client = _signedIn(server, token: 'the-old-token');

    final Future<void> call = expectLater(
      client.get(_poll),
      throwsA(isA<ApiException>()),
    );

    await server.reached;
    client.token = 'the-new-token';
    server.answer();
    await call;

    expect(server.endedTheSession, isFalse);
  });

  // The one the password change is about. The server raises the account's
  // token version as it answers, so a poll already out is refused while the
  // reply carrying the replacement is still in transit — and at that moment
  // the refused poll is still carrying what this client calls its token.
  test('a refusal while a token is being renewed ends nothing', () async {
    final _Server server = _Server()..answer();
    final ApiClient client = _signedIn(server);

    await client.renewing(() async {
      await expectLater(client.get(_poll), throwsA(isA<ApiException>()));
    });

    expect(server.endedTheSession, isFalse);
  });

  // And it lasts exactly as long as that call does: a token that really did
  // die is caught by the next poll rather than never.
  test('the next refusal after a renewal ends the session', () async {
    final _Server server = _Server()..answer();
    final ApiClient client = _signedIn(server);

    await client.renewing(() async {});

    await expectLater(client.get(_poll), throwsA(isA<ApiException>()));

    expect(server.endedTheSession, isTrue);
  });

  // A password change the server refused — the wrong current password — throws
  // straight through `renewing`. If the guard were released on the way out
  // rather than in a `finally`, it would stand for the rest of the session and
  // this client could never end one again.
  test('a renewal refused by the server still releases the guard', () async {
    final _Server server = _Server(statuses: <String, int>{_change: 400})
      ..answer();
    final ApiClient client = _signedIn(server);

    await expectLater(
      client.renewing(() => client.post(_change)),
      throwsA(isA<ApiException>()),
    );

    await expectLater(client.get(_poll), throwsA(isA<ApiException>()));

    expect(server.endedTheSession, isTrue);
  });

  // The same, for the failure that answers nothing at all rather than a status.
  test('a renewal that timed out still releases the guard', () async {
    final _Server server = _Server(timesOutOn: _change)..answer();
    final ApiClient client = _signedIn(server);

    await expectLater(
      client.renewing(() => client.post(_change)),
      throwsA(isA<ApiException>()),
    );

    await expectLater(client.get(_poll), throwsA(isA<ApiException>()));

    expect(server.endedTheSession, isTrue);
  });
}

ApiClient _signedIn(_Server server, {String token = 'the-token'}) =>
    ApiClient(baseUrl: Uri.parse('http://localhost:5000'), adapter: server)
      ..token = token
      ..onUnauthorized = server.recordTheEnding;

// Answers a call by the path it was made to, and not before a test says so —
// which is what lets a test move the token while a call is still out. A path
// nothing was scripted for is refused, because a refusal is what these tests
// are about.
class _Server implements HttpClientAdapter {
  _Server({this.statuses = const <String, int>{}, this.timesOutOn});

  final Map<String, int> statuses;
  final String? timesOutOn;

  final Completer<void> _reached = Completer<void>();
  final Completer<void> _answer = Completer<void>();

  bool endedTheSession = false;

  Future<void> get reached => _reached.future;

  void recordTheEnding() => endedTheSession = true;

  void answer() {
    if (!_answer.isCompleted) {
      _answer.complete();
    }
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!_reached.isCompleted) {
      _reached.complete();
    }

    await _answer.future;

    if (options.path == timesOutOn) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 30),
        requestOptions: options,
      );
    }

    final int status = statuses[options.path] ?? 401;

    return ResponseBody.fromString(
      '{"status":$status,"message":"${_said(status)}","traceId":"test"}',
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  static String _said(int status) => status == 401
      ? 'This request carried no signed in user.'
      : 'One or more values are not valid.';
}
