import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slot_query.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slots_repository.dart';
import 'package:gostio_desktop/features/experiences/presentation/experience_slots_tab.dart';
import 'package:gostio_desktop/features/reservations/data/reservations_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/bookings_double.dart';

void main() {
  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Slots(failing: true)));
    await tester.pumpAndSettle();

    expect(find.text('The terms could not be read.'), findsOneWidget);
    expect(find.text('Trace 7c30f1'), findsOneWidget);
  });

  testWidgets('an experience with no term at all is named as the reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Slots(rows: const <ExperienceSlot>[])));
    await tester.pumpAndSettle();

    expect(find.text('No terms in this window'), findsOneWidget);
  });

  testWidgets('a term is read with what it holds and what is left', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Slots()));
    await tester.pumpAndSettle();

    expect(find.text('4 h'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('Open'), findsWidgets);
  });

  testWidgets('a term with reservations against it cannot be deleted', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Slots(), held: 2));
    await tester.pumpAndSettle();
    await _openTheTerm(tester);

    expect(_deleteButton(tester).onPressed, isNull);
  });

  // A cancelled booking frees the place and keeps the foreign key, so a term
  // holding nothing but those is one the server still refuses to delete.
  testWidgets('a term whose only bookings were cancelled is held too', (
    WidgetTester tester,
  ) async {
    final _Slots slots = _Slots(rows: <ExperienceSlot>[_slot(booked: 0)]);
    await tester.pumpWidget(_tab(slots, held: 1));
    await tester.pumpAndSettle();
    await _openTheTerm(tester);

    expect(_deleteButton(tester).onPressed, isNull);
    expect(
      find.byTooltip(
        'This slot has reservations that have to be kept, so it cannot be '
        'deleted.',
      ),
      findsOneWidget,
    );
  });

  // The server refuses a capacity below what is booked, so the dialog does.
  testWidgets('a capacity below what is booked is refused before the write', (
    WidgetTester tester,
  ) async {
    final _Slots slots = _Slots();
    await tester.pumpWidget(_tab(slots));
    await tester.pumpAndSettle();
    await _openTheTerm(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Places'), '2');
    await tester.tap(find.text('Save term'));
    await tester.pumpAndSettle();

    expect(slots.saved, isEmpty);
    expect(
      find.textContaining('cannot go below what is booked'),
      findsOneWidget,
    );
  });

  testWidgets('a term that is free of bookings can be closed and deleted', (
    WidgetTester tester,
  ) async {
    final _Slots slots = _Slots(rows: <ExperienceSlot>[_slot(booked: 0)]);
    await tester.pumpWidget(_tab(slots));
    await tester.pumpAndSettle();
    await _openTheTerm(tester);

    expect(_deleteButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Open for booking'));
    await tester.tap(find.text('Save term'));
    await tester.pumpAndSettle();

    expect(slots.saved, <(int, int, bool)>[(4, 8, false)]);
  });
}

Future<void> _openTheTerm(WidgetTester tester) async {
  final Finder row = find.text('4 h');

  await tester.tap(row);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(row);
  await tester.pumpAndSettle();
}

TextButton _deleteButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Delete'));

Widget _tab(_Slots slots, {int held = 0}) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<ExperienceSlotsRepository>.value(value: slots),
    Provider<ReservationsRepository>.value(value: _Reservations(held)),
  ],
  child: MaterialApp(
    home: const Scaffold(
      body: ExperienceSlotsTab(experienceId: 12, durationMinutes: 240),
    ),
  ),
);

class _Reservations extends BookingsDouble {
  const _Reservations(this._held);

  final int _held;

  @override
  Future<int> countForSlot(int slotId) async => _held;
}

class _Slots implements ExperienceSlotsRepository {
  _Slots({this.failing = false, List<ExperienceSlot>? rows})
    : rows = rows ?? <ExperienceSlot>[_slot()];

  final bool failing;
  final List<ExperienceSlot> rows;
  final List<(int, int, bool)> saved = <(int, int, bool)>[];

  @override
  Future<PagedResult<ExperienceSlot>> search(
    int experienceId, {
    required ExperienceSlotQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    if (failing) {
      throw const ApiException(
        message: 'The terms could not be read.',
        statusCode: 500,
        traceId: '7c30f1',
      );
    }

    return PagedResult<ExperienceSlot>(
      items: rows,
      page: page,
      pageSize: pageSize,
      totalCount: rows.length,
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
  }) => throw UnimplementedError();

  @override
  Future<ExperienceSlot> update(
    int experienceId,
    int slotId, {
    required int capacity,
    required bool isActive,
  }) async {
    saved.add((slotId, capacity, isActive));

    return rows.first;
  }

  @override
  Future<void> delete(int experienceId, int slotId) async {}
}

ExperienceSlot _slot({int booked = 3}) => ExperienceSlot(
  id: 4,
  experienceId: 12,
  startTime: DateTime.utc(2026, 5, 1, 7),
  endTime: DateTime.utc(2026, 5, 1, 11),
  durationMinutes: 240,
  capacity: 8,
  remainingCapacity: 8 - booked,
  isActive: true,
);
