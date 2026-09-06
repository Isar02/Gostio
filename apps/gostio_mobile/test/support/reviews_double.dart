import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/reviews/data/reviews_repository.dart';

import 'review_fixture.dart';

// The reviews an account has written and the one against a booking, answered
// without a socket. Every write records what it was asked to send, so a test
// says what it expects the screen to have written rather than reading it back
// off the screen.
class ReviewsDouble implements ReviewsRepository {
  ReviewsDouble({
    this.written = const <Review>[],
    this.against,
    Review? answers,
    this.readFailure,
    this.writeFailure,
    this.listFailure,
    this.holdsTheWrite = false,
    this.holdsTheRead = false,
  }) : answers = answers ?? review();

  // What this account has written, which is what the profile list reads.
  final List<Review> written;

  // The review against the one booking a screen is opened on, or none.
  final Review? against;

  // What a write answers with, which is the row the server then holds.
  final Review answers;

  final ApiException? readFailure;
  final ApiException? writeFailure;
  final ApiException? listFailure;
  final bool holdsTheWrite;
  final bool holdsTheRead;

  final List<int> read = <int>[];
  final List<int> pagesAsked = <int>[];
  final List<({int reservationId, int rating, String? comment})> posted =
      <({int reservationId, int rating, String? comment})>[];
  final List<({int reservationId, int rating, String? comment})> changed =
      <({int reservationId, int rating, String? comment})>[];
  final List<int> takenDown = <int>[];

  final Completer<void> _write = Completer<void>();
  final Completer<void> _read = Completer<void>();

  void answerTheWrite() => _write.complete();

  void answerTheRead() => _read.complete();

  @override
  Future<PagedResult<Review>> byGuest({
    required int guestId,
    required int page,
    required int pageSize,
  }) async {
    pagesAsked.add(page);

    if (listFailure case final ApiException refused) {
      throw refused;
    }

    final int from = ((page - 1) * pageSize).clamp(0, written.length);
    final int to = (from + pageSize).clamp(0, written.length);

    return PagedResult<Review>(
      items: written.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: written.length,
    );
  }

  @override
  Future<Review?> forBooking(int reservationId) async {
    read.add(reservationId);

    if (holdsTheRead) {
      await _read.future;
    }

    if (readFailure case final ApiException refused) {
      throw refused;
    }

    return against;
  }

  @override
  Future<Review> write(
    int reservationId, {
    required int rating,
    String? comment,
  }) async {
    posted.add((
      reservationId: reservationId,
      rating: rating,
      comment: comment,
    ));

    return _answered();
  }

  @override
  Future<Review> rewrite(
    int reservationId, {
    required int rating,
    String? comment,
  }) async {
    changed.add((
      reservationId: reservationId,
      rating: rating,
      comment: comment,
    ));

    return _answered();
  }

  @override
  Future<void> takeDown(int reservationId) async {
    takenDown.add(reservationId);

    if (holdsTheWrite) {
      await _write.future;
    }

    if (writeFailure case final ApiException refused) {
      throw refused;
    }
  }

  Future<Review> _answered() async {
    if (holdsTheWrite) {
      await _write.future;
    }

    if (writeFailure case final ApiException refused) {
      throw refused;
    }

    return answers;
  }
}
