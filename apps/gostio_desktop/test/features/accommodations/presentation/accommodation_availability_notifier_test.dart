import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability_repository.dart';
import 'package:gostio_desktop/features/accommodations/data/availability_draft.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_availability_notifier.dart';
import 'package:gostio_desktop/features/accommodations/presentation/availability_month.dart';
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

  test(
    'a span reaching over an entry is refused before it is written',
    () async {
      final _Availability entries = _Availability(
        rows: <AccommodationAvailability>[_blocked],
      );
      final AccommodationAvailabilityNotifier calendar = _calendar(entries);
      await calendar.open(_september);

      calendar
        ..chooseDay(_day(calendar, 8))
        ..chooseDay(_day(calendar, 14));

      expect(calendar.selection, (DateTime(2026, 9, 8), DateTime(2026, 9, 14)));
      expect(calendar.canWriteSelection, isFalse);
      expect(calendar.isSelectionRefused, isTrue);
    },
  );

  test('a day already carrying an entry opens the entry', () async {
    final _Availability entries = _Availability(
      rows: <AccommodationAvailability>[_blocked],
    );
    final AccommodationAvailabilityNotifier calendar = _calendar(entries);
    await calendar.open(_september);

    calendar.chooseDay(_day(calendar, 11));

    expect(calendar.chosenEntry?.id, 1);
    expect(calendar.selection, isNull);
    expect(calendar.highlight, (DateTime(2026, 9, 10), DateTime(2026, 9, 12)));
  });

  test(
    'the span the pointer is over follows it only until it is settled',
    () async {
      final AccommodationAvailabilityNotifier calendar = _calendar(
        _Availability(),
      );
      await calendar.open(_september);

      calendar
        ..chooseDay(_day(calendar, 8))
        ..reachTo(_day(calendar, 10));

      expect(calendar.selection, (DateTime(2026, 9, 8), DateTime(2026, 9, 10)));

      calendar
        ..chooseDay(_day(calendar, 9))
        ..reachTo(_day(calendar, 14));

      expect(calendar.selection, (DateTime(2026, 9, 8), DateTime(2026, 9, 9)));
      expect(calendar.selectedNights, 2);
    },
  );

  test('an entry that stood is read back and clears what was chosen', () async {
    final _Availability entries = _Availability();
    final AccommodationAvailabilityNotifier calendar = _calendar(entries);
    await calendar.open(_september);

    calendar
      ..chooseDay(_day(calendar, 8))
      ..chooseDay(_day(calendar, 9));

    final ApiException? refused = await calendar.add(
      AvailabilityDraft.blocked(
        startDate: DateTime(2026, 9, 8),
        endDate: DateTime(2026, 9, 9),
      ),
    );

    expect(refused, isNull);
    expect(entries.added.length, 1);
    expect(entries.reads, 2);
    expect(calendar.selection, isNull);
  });

  test(
    'an entry the API refused answers the caller and stays chosen',
    () async {
      final _Availability entries = _Availability()
        ..writeFailure = const ApiException(
          message: 'One or more values are not valid.',
          statusCode: 400,
          errors: <String, List<String>>{
            'PriceOverride': <String>['A nightly price is above zero.'],
          },
        );
      final AccommodationAvailabilityNotifier calendar = _calendar(entries);
      await calendar.open(_september);

      calendar
        ..chooseDay(_day(calendar, 8))
        ..chooseDay(_day(calendar, 9));

      final ApiException? refused = await calendar.add(
        AvailabilityDraft.open(
          startDate: DateTime(2026, 9, 8),
          endDate: DateTime(2026, 9, 9),
          price: 90,
        ),
      );

      expect(
        refused?.firstMessageFor('priceOverride'),
        'A nightly price is above zero.',
      );
      expect(calendar.failureMessage, isNull);
      expect(calendar.selection, (DateTime(2026, 9, 8), DateTime(2026, 9, 9)));
      expect(entries.reads, 1);
    },
  );

  test('a write the calendar could not read back stops the next one', () async {
    final _Availability entries = _Availability();
    final AccommodationAvailabilityNotifier calendar = _calendar(entries);
    await calendar.open(_september);

    calendar
      ..chooseDay(_day(calendar, 8))
      ..chooseDay(_day(calendar, 9));

    entries.failure = const ApiException(
      message: 'The calendar could not be read.',
      statusCode: 503,
    );

    final ApiException? refused = await calendar.add(
      AvailabilityDraft.blocked(
        startDate: DateTime(2026, 9, 8),
        endDate: DateTime(2026, 9, 9),
      ),
    );

    // The write stood, so the dialog closes; what cannot stand is a second one
    // written from a grid that has never seen the first.
    expect(refused, isNull);
    expect(entries.added.length, 1);
    expect(calendar.isStale, isTrue);
    expect(calendar.isSelectionRefused, isFalse);
    expect(calendar.canWriteSelection, isFalse);

    entries.failure = null;
    await calendar.load();

    expect(calendar.isStale, isFalse);
  });

  test(
    'a removal that failed says so over the month it left standing',
    () async {
      final _Availability entries =
          _Availability(rows: <AccommodationAvailability>[_blocked])
            ..writeFailure = const ApiException(
              message: 'No availability range has the id 1.',
              statusCode: 404,
            );
      final AccommodationAvailabilityNotifier calendar = _calendar(entries);
      await calendar.open(_september);

      calendar.chooseDay(_day(calendar, 11));
      await calendar.removeChosenEntry();

      expect(calendar.failureMessage, 'No availability range has the id 1.');
      expect(calendar.shown?.blockedDays, 3);
      expect(calendar.chosenEntry?.id, 1);
    },
  );
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

AvailabilityDay _day(AccommodationAvailabilityNotifier calendar, int day) =>
    calendar.shown!.days.firstWhere(
      (AvailabilityDay candidate) =>
          candidate.isInMonth && candidate.date == DateTime(2026, 9, day),
    );

class _Availability implements AccommodationAvailabilityRepository {
  _Availability({this.rows = const <AccommodationAvailability>[]});

  final List<AccommodationAvailability> rows;
  final List<AvailabilityDraft> added = <AvailabilityDraft>[];
  final List<int> removed = <int>[];

  int reads = 0;
  Completer<void>? gate;
  ApiException? failure;
  ApiException? writeFailure;

  @override
  Future<List<AccommodationAvailability>> forWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) async {
    reads++;

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
  ) async {
    if (writeFailure case final ApiException refused) {
      throw refused;
    }

    added.add(draft);

    return _blocked;
  }

  @override
  Future<void> delete(int accommodationId, int availabilityId) async {
    if (writeFailure case final ApiException refused) {
      throw refused;
    }

    removed.add(availabilityId);
  }
}

class _Reservations implements ReservationsRepository {
  @override
  Future<int> countForExperience(int experienceId) async => 0;
  @override
  Future<int> countForSlot(int slotId) async => 0;

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
