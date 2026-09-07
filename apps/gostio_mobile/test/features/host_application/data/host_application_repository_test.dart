import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/host_application/data/host_application_repository.dart';

// The two calls a guest makes about hosting. The search route answers a page
// rather than a row, and what this client wants from it is where the account
// stands — so the paging is what is checked here, through the whole of the
// transport rather than around it.
void main() {
  late _Api api;

  setUp(() async => api = await _Api.listening());

  tearDown(() async => api.close());

  test('the standing is the newest row, asked for one at a time', () async {
    api.answers(200, _page(_pending));

    final HostApplication? standing = await api.applications.mine();

    expect(standing?.id, 71);
    expect(standing?.standing, HostApplicationStatus.pending);
    expect(api.calls.single.method, 'GET');
    expect(api.calls.single.path, '/api/host-verification-requests');
    expect(api.calls.single.query, 'page=1&pageSize=1');
  });

  // An account that has never applied is an empty page rather than a refusal,
  // and it is the answer the screen opens on.
  test('an account that has never applied reads as none', () async {
    api.answers(200, _page(null));

    expect(await api.applications.mine(), isNull);
  });

  // No id and no body: who is applying is what the token says, and there is
  // nothing else for this client to send.
  test('applying posts the account and nothing else', () async {
    api.answers(201, _pending);

    final HostApplication made = await api.applications.apply();

    expect(made.id, 71);
    expect(api.calls.single.method, 'POST');
    expect(api.calls.single.path, '/api/host-verification-requests');
    expect(api.bodies, isEmpty);
  });
}

const String _pending =
    '{"id":71,"userId":12,"username":"emina.b",'
    '"applicantName":"Emina Begić","status":"Pending",'
    '"submittedAt":"2026-08-30T09:00:00Z"}';

String _page(String? row) =>
    '{"items":[${row ?? ''}],"page":1,"pageSize":1,'
    '"totalCount":${row == null ? 0 : 1},"totalPages":${row == null ? 0 : 1}}';

// An API on the loopback that answers everything the same way and records what
// it was asked, which is what the two calls are told apart by.
class _Api {
  _Api(this._server) {
    applications = HostApplicationRepository(
      ApiClient(baseUrl: Uri.parse('http://127.0.0.1:${_server.port}'))
        ..token = 'the-token',
    );

    unawaited(_serve());
  }

  static Future<_Api> listening() async =>
      _Api(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  late final HostApplicationRepository applications;

  final List<({String method, String path, String query})> calls =
      <({String method, String path, String query})>[];
  final List<String> bodies = <String>[];

  int _status = 200;
  String _body = '{}';

  void answers(int status, String body) {
    _status = status;
    _body = body;
  }

  Future<void> close() => _server.close(force: true);

  Future<void> _serve() async {
    await for (final HttpRequest request in _server) {
      calls.add((
        method: request.method,
        path: request.uri.path,
        query: request.uri.query,
      ));

      final String sent = await utf8.decodeStream(request);
      if (sent.isNotEmpty) {
        bodies.add(sent);
      }

      request.response
        ..statusCode = _status
        ..headers.contentType = ContentType.json
        ..write(_body);
      await request.response.close();
    }
  }
}
