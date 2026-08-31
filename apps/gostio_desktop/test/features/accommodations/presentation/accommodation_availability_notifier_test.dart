import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability_repository.dart';
import 'package:gostio_desktop/features/accommodations/data/availability_draft.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_availability_notifier.dart';
import 'package:gostio_desktop/features/reservations/data/reservation.dart';
import 'package:gostio_desktop/features/reservations/data/reservations_repository.dart';

void main() {
  test(
    'a month left behind does not draw over the one asked for later',
    () async {
      final Completer<void> slow = Completer<void>();
      final _Availability entries = _Availability()..gate = slow;
      final AccommodationAvailabilityNotifier calendar = _calendar(entries);

      final Future<void> left = calendar.open(_september);
      await calendar.open(_october);

      expect(calendar.month, _october);

      slow.complete();
      await left;

      expect(calendar.month, _october);
    },
  );

  test('a month the API refused leaves the one on screen whole', () async {
    final _Availability entries = _Availability(
      rows: <AccommodationAvailability>[_blocked],
    );
    final AccommodationAvailabilityNotifier calendar = _calendar(entries);
    await calendar.open(_september);

    entries.failure = const ApiException(
      message: 'The calendar could not be read.',
      statusCode: 503,
      traceId: 'a91c02',
    );
    await calendar.open(_october);

    expect(calendar.month, _september);
    expect(calendar.shown?.blockedDays, 3);
    expect(calendar.failureMessage, 'The calendar could not be read.');
    expect(calendar.failureTraceId, 'a91c02');
  });
}

final DateTime _september = DateTime(2026, 9);
final DateTime _october = DateTime(2026, 10);

final AccommodationAvailability _blocked = AccommodationAvailability(
  id: 1,
  accommodationId: 7,
  startDate: DateTime(2026, 9, 10),
  endDate: DateTime(2026, 9, 12),
  isAvailable: false,
);

AccommodationAvailabilityNotifier _calendar(_Availability entries) =>
    AccommodationAvailabilityNotifier(
      entries,
      _Reservations(),
      accommodationId: 7,
    );

class _Availability implements AccommodationAvailabilityRepository {
  _Availability({this.rows = const <AccommodationAvailability>[]});

  final List<AccommodationAvailability> rows;

  Completer<void>? gate;
  ApiException? failure;

  @override
  Future<List<AccommodationAvailability>> forWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) async {
    final Completer<void>? waiting = gate;
    gate = null;
    if (waiting != null) {
      await waiting.future;
    }

    if (failure case final ApiException refused) {
      throw refused;
    }

    return rows;
  }

  @override
  Future<AccommodationAvailability> add(
    int accommodationId,
    AvailabilityDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<void> delete(int accommodationId, int availabilityId) =>
      throw UnimplementedError();
}

class _Reservations implements ReservationsRepository {
  @override
  Future<int> countForAccommodation(int accommodationId) =>
      throw UnimplementedError();

  @override
  Future<List<Reservation>> forAccommodationWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) async => const <Reservation>[];
}
