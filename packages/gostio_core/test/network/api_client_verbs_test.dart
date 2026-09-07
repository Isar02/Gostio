import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

// What actually goes out on the wire for the verbs whose shape is not obvious
// from the call.
void main() {
  // Removing this device's push registration names the token in the body
  // rather than in the path, so it stays out of the places a URL is written
  // down. A delete that dropped the body would reach the server as a request
  // naming nothing.
  test('a delete carries the body it was given', () async {
    final _Recorder recorder = _Recorder();
    final ApiClient client = ApiClient(
      baseUrl: Uri.parse('http://localhost:5000'),
      adapter: recorder,
    )..token = 'the-token';

    await client.delete(
      '/notifications/device-tokens',
      body: <String, String>{'token': 'device-token', 'platform': 'Android'},
    );

    expect(recorder.method, 'DELETE');
    expect(recorder.path, '/notifications/device-tokens');
    expect(recorder.body, '{"token":"device-token","platform":"Android"}');
  });

  test('a delete with nothing to say carries no body', () async {
    final _Recorder recorder = _Recorder();
    final ApiClient client = ApiClient(
      baseUrl: Uri.parse('http://localhost:5000'),
      adapter: recorder,
    )..token = 'the-token';

    await client.delete('/favorites/accommodations/1');

    expect(recorder.body, isEmpty);
  });
}

// Answers everything with no content and keeps what it was asked.
class _Recorder implements HttpClientAdapter {
  String? method;
  String? path;
  String body = '';

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    method = options.method;
    path = options.path;

    if (requestStream != null) {
      final List<int> sent = <int>[
        await for (final Uint8List chunk in requestStream) ...chunk,
      ];
      body = utf8.decode(sent);
    }

    return ResponseBody.fromString(
      '',
      204,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
