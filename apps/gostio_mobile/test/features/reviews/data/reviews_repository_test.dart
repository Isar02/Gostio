import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/reviews/data/reviews_repository.dart';

// The one route on this client whose refusal is an answer, and the three
// writes that share an address with it.
//
// This client does not name the transport its API is reached over, so the
// answers are scripted by a server on the loopback rather than by an adapter
// inside the client: what is being checked is what the repository makes of a
// status, and that is worth checking through the whole of it.
void main() {
  late _Api api;

  setUp(() async => api = await _Api.listening());

  tearDown(() async => api.close());

  test('a booking nobody has reviewed answers with no review', () async {
    api.answers(404, '{"status":404,"message":"That has no review."}');

    expect(await api.reviews.forBooking(501), isNull);
    expect(api.calls.single, ('GET', '/api/reservations/501/review'));
  });

  // Only the missing row is an answer. Anything else the server refuses is a
  // refusal, and a section that swallowed it would invite a second review of a
  // booking the server may already hold one for.
  test('a refusal that is not a missing row is still a refusal', () async {
    api.answers(500, '{"status":500,"message":"That could not be read."}');

    await expectLater(
      api.reviews.forBooking(501),
      throwsA(isA<ApiException>()),
    );
  });

  test('a review is left with a post and changed with a put', () async {
    api.answers(200, _review);

    final Review written = await api.reviews.write(
      501,
      rating: 5,
      comment: 'Worth the stairs.',
    );
    await api.reviews.rewrite(501, rating: 4);

    expect(written.rating, 5);
    expect(api.calls, <(String, String)>[
      ('POST', '/api/reservations/501/review'),
      ('PUT', '/api/reservations/501/review'),
    ]);
    expect(api.bodies.first, <String, dynamic>{
      'rating': 5,
      'comment': 'Worth the stairs.',
    });
    // Words the guest left out are sent as none rather than as an empty
    // string, which the server would store and print back at them.
    expect(api.bodies.last, <String, dynamic>{'rating': 4, 'comment': null});
  });

  test('a review is taken down through the booking it is about', () async {
    api.answers(204, '');

    await api.reviews.takeDown(501);

    expect(api.calls.single, ('DELETE', '/api/reservations/501/review'));
  });
}

const String _review =
    '{"id":91,"reservationId":501,"guestId":12,"guestName":"Emina Begić",'
    '"accommodationId":1,"listingTitle":"Loft over the river","rating":5,'
    '"comment":"Worth the stairs.","createdAt":"2026-08-20T10:00:00Z"}';

// An API on the loopback that answers everything the same way and records what
// it was asked, which is what these four calls are told apart by.
class _Api {
  _Api(this._server) {
    reviews = ReviewsRepository(
      ApiClient(baseUrl: Uri.parse('http://127.0.0.1:${_server.port}'))
        ..token = 'the-token',
    );

    unawaited(_serve());
  }

  static Future<_Api> listening() async =>
      _Api(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  late final ReviewsRepository reviews;

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
