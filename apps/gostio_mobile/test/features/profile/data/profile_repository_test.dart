import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/profile/data/password_draft.dart';
import 'package:gostio_mobile/features/profile/data/profile_repository.dart';

// The one call on this client that replaces the token it is made with.
//
// The window it has to close is short and cannot be reached from a test: the
// server raises the account's token version as it answers, so every other call
// already out is refused from that moment until this client holds the
// replacement, and `renewing` is what stops those refusals from being read as a
// session that is over. What a test can hold is the shape that keeps the window
// inside the guard — the replacement is taken up during the call rather than
// handed back for the caller to adopt after it, which is why this method
// answers nothing.
void main() {
  late _Api api;

  setUp(() async => api = await _Api.listening());

  tearDown(() async => api.close());

  const PasswordDraft draft = PasswordDraft(
    currentPassword: 'the-old-one',
    newPassword: 'the-new-one',
    confirmNewPassword: 'the-new-one',
  );

  test('the three fields are sent and the replacement is taken up', () async {
    api.answers(200, _auth);

    String? adopted;
    final Future<void> changing = api.profile.changePassword(
      draft,
      adopt: (String token) => adopted = token,
    );

    // Nothing is adopted until the reply is in, and the call is not over until
    // it has been.
    expect(adopted, isNull);
    await changing;

    expect(adopted, 'the-new-token');
    expect(api.calls.single, ('POST', '/api/auth/change-password'));
    expect(api.bodies.single, <String, dynamic>{
      'currentPassword': 'the-old-one',
      'newPassword': 'the-new-one',
      'confirmNewPassword': 'the-new-one',
    });
  });

  test('a refused change adopts nothing', () async {
    api.answers(
      400,
      '{"status":400,"message":"That is not your current password."}',
    );

    bool adopted = false;

    await expectLater(
      api.profile.changePassword(draft, adopt: (_) => adopted = true),
      throwsA(isA<ApiException>()),
    );

    expect(adopted, isFalse);
  });
}

const String _auth =
    '{"token":"the-new-token","expiresAt":"2026-09-08T11:00:00Z",'
    '"user":{"id":12,"firstName":"Emina","lastName":"Begić",'
    '"username":"emina.b","email":"emina.b@gostio.test",'
    '"phoneNumber":null,"hasProfileImage":false,"isActive":true,'
    '"roles":["Guest"],"createdAt":"2026-05-04T11:00:00Z"}}';

// An API on the loopback that answers everything the same way and records what
// it was asked.
class _Api {
  _Api(this._server) {
    profile = ProfileRepository(
      ApiClient(baseUrl: Uri.parse('http://127.0.0.1:${_server.port}'))
        ..token = 'the-token',
    );

    unawaited(_serve());
  }

  static Future<_Api> listening() async =>
      _Api(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  late final ProfileRepository profile;

  final List<(String, String)> calls = <(String, String)>[];
  final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];

  int _status = 200;
  String _body = '{}';

  void answers(int status, String body) {
    _status = status;
    _body = body;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _serve() async {
    await for (final HttpRequest request in _server) {
      calls.add((request.method, request.uri.path));

      final String sent = await utf8.decodeStream(request);
      if (sent.isNotEmpty) {
        bodies.add(jsonDecode(sent) as Map<String, dynamic>);
      }

      request.response
        ..statusCode = _status
        ..headers.contentType = ContentType.json
        ..write(_body);
      await request.response.close();
    }
  }
}
