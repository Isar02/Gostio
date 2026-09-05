import 'dart:async';

import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/core/calendar/date_range.dart';
import 'package:gostio_mobile/features/booking/data/booking_repository.dart';

import 'booking_fixture.dart';

// Bookings answered without a socket. Every write records what it was asked to
// send, so a test says what it expects the screen to have written rather than
// reading it back off the screen.
class BookingDouble implements BookingRepository {
  BookingDouble({
    this.slots = const <ExperienceSlot>[],
    this.alreadyHeld = const <int>{},
    Reservation? made,
    this.failure,
    this.termsFailure,
    this.holdsTheCall = false,
  }) : made = made ?? stayBooking();

  final List<ExperienceSlot> slots;
  final Set<int> alreadyHeld;
  final Reservation made;
  final ApiException? failure;
  final ApiException? termsFailure;
  final bool holdsTheCall;

  final List<({int accommodationId, DateRange dates, int guestCount})>
  staysBooked = <({int accommodationId, DateRange dates, int guestCount})>[];

  final List<({int slotId, int guestCount})> termsBooked =
      <({int slotId, int guestCount})>[];

  final List<int> pagesAsked = <int>[];

  final Completer<void> _answer = Completer<void>();

  void answer() => _answer.complete();

  @override
  Future<Reservation> bookStay({
    required int accommodationId,
    required DateRange dates,
    required int guestCount,
  }) async {
    staysBooked.add((
      accommodationId: accommodationId,
      dates: dates,
      guestCount: guestCount,
    ));

    return _answered();
  }

  @override
  Future<Reservation> bookTerm({
    required int slotId,
    required int guestCount,
  }) async {
    termsBooked.add((slotId: slotId, guestCount: guestCount));

    return _answered();
  }

  @override
  Future<PagedResult<ExperienceSlot>> terms(
    int experienceId, {
    required int page,
    required int pageSize,
  }) async {
    pagesAsked.add(page);

    if (termsFailure case final ApiException refused) {
      throw refused;
    }

    final int from = ((page - 1) * pageSize).clamp(0, slots.length);
    final int to = (from + pageSize).clamp(0, slots.length);

    return PagedResult<ExperienceSlot>(
      items: slots.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: slots.length,
    );
  }

  @override
  Future<Set<int>> termsAlreadyHeld(int experienceId) async => alreadyHeld;

  Future<Reservation> _answered() async {
    if (holdsTheCall) {
      await _answer.future;
    }

    if (failure case final ApiException refused) {
      throw refused;
    }

    return made;
  }
}
