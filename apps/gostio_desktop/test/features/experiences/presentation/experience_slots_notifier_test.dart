import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slot.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slot_query.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slots_repository.dart';
import 'package:gostio_desktop/features/experiences/presentation/experience_slots_notifier.dart';

void main() {
  test('the window starts at today rather than at the first term', () async {
    final _Slots slots = _Slots();
    final ExperienceSlotsNotifier notifier = _notifier(slots);

    await notifier.reload();

    final DateTime today = DateTime.now();

    expect(notifier.query.from, DateTime(today.year, today.month, today.day));
    expect(notifier.query.to, isNull);
  });

  test('a term that landed is read back rather than patched in', () async {
    final _Slots slots = _Slots();
    final ExperienceSlotsNotifier notifier = _notifier(slots);
    await notifier.reload();

    final ApiException? refused = await notifier.add(
      startTime: DateTime(2026, 5, 1, 9),
      capacity: 8,
    );

    expect(refused, isNull);
    expect(slots.reads, 2);
    expect(notifier.isWriting, isFalse);
  });

  test('a refusal is answered to the caller, not left on the tab', () async {
    final _Slots slots = _Slots()
      ..refusal = const ApiException(
        message:
            'This term runs into one the experience already has. Remove that '
            'one before adding this.',
        statusCode: 409,
      );
    final ExperienceSlotsNotifier notifier = _notifier(slots);
    await notifier.reload();

    final ApiException? refused = await notifier.add(
      startTime: DateTime(2026, 5, 1, 9),
      capacity: 8,
    );

    expect(refused?.statusCode, 409);
    expect(notifier.failureMessage, isNull);
    expect(slots.reads, 1);
  });

  test('closing a term reads the page it is on again', () async {
    final _Slots slots = _Slots();
    final ExperienceSlotsNotifier notifier = _notifier(slots);
    await notifier.reload();

    await notifier.save(4, capacity: 8, isActive: false);

    expect(slots.saved, <(int, int, bool)>[(4, 8, false)]);
    expect(slots.reads, 2);
  });

  // The write stood, so the dialog closed on a success; the rows behind it are
  // the ones from before it and cannot be written from again.
  test('a write whose read back failed leaves the page behind', () async {
    final _Slots slots = _Slots();
    final ExperienceSlotsNotifier notifier = _notifier(slots);
    await notifier.reload();

    slots.readFailure = const ApiException(
      message: 'The terms could not be read.',
      statusCode: 503,
    );

    final ApiException? refused = await notifier.add(
      startTime: DateTime(2026, 5, 1, 9),
      capacity: 8,
    );

    expect(refused, isNull);
    expect(notifier.isStale, isTrue);
    expect(notifier.failureMessage, 'The terms could not be read.');
  });

  test('a read that lands puts the page back in step', () async {
    final _Slots slots = _Slots();
    final ExperienceSlotsNotifier notifier = _notifier(slots);
    await notifier.reload();

    slots.readFailure = const ApiException(
      message: 'The terms could not be read.',
      statusCode: 503,
    );
    await notifier.add(startTime: DateTime(2026, 5, 1, 9), capacity: 8);

    slots.readFailure = null;
    await notifier.reload();

    expect(notifier.isStale, isFalse);
    expect(notifier.failureMessage, isNull);
  });

  // A read whose answer was thrown away because a later one was already asked
  // for has settled nothing, so it cannot be what says the rows are current.
  test('a read that was overtaken leaves the page where it was', () async {
    final _Slots slots = _Slots();
    final ExperienceSlotsNotifier notifier = _notifier(slots);
    await notifier.reload();

    slots.readFailure = const ApiException(
      message: 'The terms could not be read.',
      statusCode: 503,
    );
    await notifier.add(startTime: DateTime(2026, 5, 1, 9), capacity: 8);
    slots.readFailure = null;

    final Completer<void> overtaken = Completer<void>();
    final Completer<void> newest = Completer<void>();
    slots.gates.addAll(<Completer<void>>[overtaken, newest]);

    final Future<void> first = notifier.reload();
    final Future<void> second = notifier.apply(const ExperienceSlotQuery());

    overtaken.complete();
    await first;

    expect(notifier.isStale, isTrue);

    newest.complete();
    await second;

    expect(notifier.isStale, isFalse);
  });

  // The tab reads the flag out of the same rebuild the rows arrive in, so a
  // page put back in step is not left looking locked until the next one.
  test('the page is in step by the time the read is announced', () async {
    final _Slots slots = _Slots();
    final ExperienceSlotsNotifier notifier = _notifier(slots);
    await notifier.reload();

    slots.readFailure = const ApiException(
      message: 'The terms could not be read.',
      statusCode: 503,
    );
    await notifier.add(startTime: DateTime(2026, 5, 1, 9), capacity: 8);
    slots.readFailure = null;

    final List<bool> announced = <bool>[];
    notifier.addListener(() => announced.add(notifier.isStale));

    await notifier.reload();

    expect(announced.last, isFalse);
  });

  test('a term that could not be deleted answers its reason', () async {
    final _Slots slots = _Slots()
      ..refusal = const ApiException(
        message:
            'This slot has reservations that have to be kept, so it cannot be '
            'deleted.',
        statusCode: 409,
      );
    final ExperienceSlotsNotifier notifier = _notifier(slots);
    await notifier.reload();

    final ApiException? refused = await notifier.remove(4);

    expect(refused?.message, contains('cannot be deleted'));
    expect(slots.reads, 1);
  });
}

ExperienceSlotsNotifier _notifier(_Slots slots) {
  final ExperienceSlotsNotifier notifier = ExperienceSlotsNotifier(
    slots,
    experienceId: 12,
  );
  addTearDown(notifier.dispose);

  return notifier;
}

class _Slots implements ExperienceSlotsRepository {
  int reads = 0;
  final List<(int, int, bool)> saved = <(int, int, bool)>[];

  ApiException? refusal;

  ApiException? readFailure;

  // Held one read at a time, so a test can let a later one overtake an earlier.
  final List<Completer<void>> gates = <Completer<void>>[];

  @override
  Future<PagedResult<ExperienceSlot>> search(
    int experienceId, {
    required ExperienceSlotQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    reads++;

    if (gates.isNotEmpty) {
      await gates.removeAt(0).future;
    }

    if (readFailure case final ApiException refused) {
      throw refused;
    }

    return PagedResult<ExperienceSlot>(
      items: <ExperienceSlot>[_slot()],
      page: page,
      pageSize: pageSize,
      totalCount: 1,
    );
  }

  @override
  Future<ExperienceSlot> get(int experienceId, int slotId) =>
      throw UnimplementedError();

  @override
  Future<ExperienceSlot> add(
    int experienceId, {
    required DateTime startTime,
    required int capacity,
  }) async {
    if (refusal case final ApiException refused) {
      throw refused;
    }

    return _slot();
  }

  @override
  Future<ExperienceSlot> update(
    int experienceId,
    int slotId, {
    required int capacity,
    required bool isActive,
  }) async {
    if (refusal case final ApiException refused) {
      throw refused;
    }

    saved.add((slotId, capacity, isActive));

    return _slot();
  }

  @override
  Future<void> delete(int experienceId, int slotId) async {
    if (refusal case final ApiException refused) {
      throw refused;
    }
  }
}

ExperienceSlot _slot() => ExperienceSlot(
  id: 4,
  experienceId: 12,
  startTime: DateTime.utc(2026, 5, 1, 7),
  endTime: DateTime.utc(2026, 5, 1, 11),
  durationMinutes: 240,
  capacity: 8,
  remainingCapacity: 5,
  isActive: true,
);
