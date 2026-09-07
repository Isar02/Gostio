import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/trips/data/trip_window.dart';
import 'package:gostio_mobile/features/trips/data/trips_repository.dart';

import 'booking_fixture.dart';

// The bookings an account has made, answered without a socket. Each side of
// the split is held separately, because what the screen is being asked is
// which of the two lists it is drawing.
class TripsDouble implements TripsRepository {
  TripsDouble({
    this.upcoming = const <Reservation>[],
    this.past = const <Reservation>[],
    RefundQuote? quote,
    Reservation? cancelled,
    this.named,
    this.namedFailure,
    this.failure,
    this.quoteFailure,
    this.cancelFailure,
    this.holdsTheCancellation = false,
  }) : quote = quote ?? owedBack(),
       cancelled =
           cancelled ?? stayBooking(standing: ReservationStatus.cancelled);

  final List<Reservation> upcoming;
  final List<Reservation> past;

  // The one booking a notice names, read by its id alone.
  final Reservation? named;
  final ApiException? namedFailure;
  final RefundQuote quote;
  final Reservation cancelled;
  final ApiException? failure;
  final ApiException? quoteFailure;
  final ApiException? cancelFailure;
  final bool holdsTheCancellation;

  final Completer<void> _cancelled = Completer<void>();

  void answerTheCancellation() => _cancelled.complete();

  final List<({int guestId, TripWindow window, int page})> asked =
      <({int guestId, TripWindow window, int page})>[];

  final List<int> quoted = <int>[];

  final List<int> readById = <int>[];

  final List<({int bookingId, String reason})> calledOff =
      <({int bookingId, String reason})>[];

  @override
  Future<PagedResult<Reservation>> trips({
    required int guestId,
    required TripWindow window,
    required int page,
    required int pageSize,
  }) async {
    asked.add((guestId: guestId, window: window, page: page));

    if (failure case final ApiException refused) {
      throw refused;
    }

    final List<Reservation> all = switch (window) {
      TripWindow.upcoming => upcoming,
      TripWindow.past => past,
    };

    final int from = ((page - 1) * pageSize).clamp(0, all.length);
    final int to = (from + pageSize).clamp(0, all.length);

    return PagedResult<Reservation>(
      items: all.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: all.length,
    );
  }

  @override
  Future<Reservation> trip(int reservationId) async {
    readById.add(reservationId);

    if (namedFailure case final ApiException refused) {
      throw refused;
    }

    return named ?? stayBooking();
  }

  @override
  Future<RefundQuote> refundQuote(int reservationId) async {
    quoted.add(reservationId);

    if (quoteFailure case final ApiException refused) {
      throw refused;
    }

    return quote;
  }

  @override
  Future<Reservation> cancel(
    int reservationId, {
    required String reason,
  }) async {
    calledOff.add((bookingId: reservationId, reason: reason));

    if (holdsTheCancellation) {
      await _cancelled.future;
    }

    if (cancelFailure case final ApiException refused) {
      throw refused;
    }

    return cancelled;
  }
}
