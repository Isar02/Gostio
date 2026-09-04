import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/widgets/screen_states.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slot_query.dart';
import 'package:gostio_desktop/features/experiences/data/experience_slots_repository.dart';
import 'package:gostio_desktop/features/reservations/data/reservations_repository.dart';
import 'package:gostio_desktop/features/reservations/presentation/reservation_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/booking_fixture.dart';
import '../../../support/bookings_double.dart';

void main() {
  testWidgets('a pending booking offers both moves', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_Bookings()));
    await tester.pumpAndSettle();

    expect(_confirm(tester).onPressed, isNotNull);
    expect(_cancel(tester).onPressed, isNotNull);
  });

  // The server's state machine, drawn: a move it would refuse is disabled with
  // the reason on it rather than pressed and answered with a 400.
  testWidgets('a confirmed booking says why it cannot be confirmed again', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        _Bookings(
          reservation: booking(
            reservationStatusId: 2,
            status: 'Confirmed',
            isPaid: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_confirm(tester).onPressed, isNull);
    expect(_cancel(tester).onPressed, isNotNull);
    expect(find.byTooltip('This booking is already confirmed.'), findsOne);
  });

  testWidgets('a cancelled booking moves nowhere', (WidgetTester tester) async {
    await tester.pumpWidget(
      _screen(
        _Bookings(
          reservation: booking(reservationStatusId: 3, status: 'Cancelled'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_confirm(tester).onPressed, isNull);
    expect(_cancel(tester).onPressed, isNull);
    expect(find.byTooltip('This booking is already cancelled.'), findsOne);
  });

  // The booking names the slot and nothing about it, so when a term runs is
  // read from the term itself.
  testWidgets('a term booking says when the term runs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(_Bookings(reservation: termBooking()), slots: _Slots()),
    );
    await tester.pumpAndSettle();

    expect(find.text('The term'), findsOne);
    expect(find.text('4 h'), findsOne);
  });

  testWidgets('a booking nobody paid for says so where the charge would be', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_Bookings()));
    await tester.pumpAndSettle();

    expect(find.text('Nothing has been charged for this yet.'), findsOne);
    expect(find.text('Nothing is owed back on this booking.'), findsOne);
  });

  // A charge that could not be read is not the booking failing to load, and it
  // is not a booking nobody paid for either: the panel says which of the two.
  testWidgets('a settlement that could not be read says so where it stands', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_Bookings(paymentFails: true)));
    await tester.pumpAndSettle();

    expect(find.text('Ana Marić'), findsWidgets);
    expect(
      find.text('The charge could not be read. The API is not answering.'),
      findsOne,
    );
    expect(find.text('Nothing has been charged for this yet.'), findsNothing);
    expect(find.text('Nothing is owed back on this booking.'), findsOne);
  });

  testWidgets('cancelling waits for what it sends back', (
    WidgetTester tester,
  ) async {
    final _Bookings bookings = _Bookings(holdsTheQuote: true);

    await tester.pumpWidget(_screen(bookings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();

    expect(find.text('Reading what this sends back.'), findsOne);
    expect(_labelled(tester, 'Cancel the booking').onPressed, isNull);

    bookings.releaseTheQuote();
    await tester.pumpAndSettle();

    expect(_labelled(tester, 'Cancel the booking').onPressed, isNotNull);
  });

  testWidgets('cancelling names what it sends back and demands a reason', (
    WidgetTester tester,
  ) async {
    final _Bookings bookings = _Bookings();

    await tester.pumpWidget(_screen(bookings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();

    expect(find.textContaining('608.00 KM of 760.00 KM goes back'), findsOne);

    await tester.tap(find.text('Cancel the booking'));
    await tester.pumpAndSettle();

    expect(find.text('Say why the reservation is being cancelled.'), findsOne);
    expect(bookings.reasons, isEmpty);

    await tester.enterText(find.byType(TextFormField), 'The host is ill.');
    await tester.tap(find.text('Cancel the booking'));
    await tester.pumpAndSettle();

    expect(bookings.reasons, <String>['The host is ill.']);
  });

  testWidgets('a refused cancellation keeps the dialog and the server word', (
    WidgetTester tester,
  ) async {
    final _Bookings bookings = _Bookings(cancelFails: true);

    await tester.pumpWidget(_screen(bookings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'The host is ill.');
    await tester.tap(find.text('Cancel the booking'));
    await tester.pumpAndSettle();

    expect(
      find.text('A Completed reservation cannot become Cancelled.'),
      findsOne,
    );
    expect(find.text('Cancel the booking'), findsOne);
  });

  // The move is answered with one row, and what settled the booking moves with
  // it, so the page is read again rather than patched from that answer.
  testWidgets('a confirmed booking is read again and drawn as confirmed', (
    WidgetTester tester,
  ) async {
    final _Bookings bookings = _Bookings();

    await tester.pumpWidget(_screen(bookings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking'));
    await tester.pumpAndSettle();

    expect(bookings.confirms, 1);
    expect(bookings.reads, 2);
    expect(_confirm(tester).onPressed, isNull);
    expect(find.byTooltip('This booking is already confirmed.'), findsOne);
  });

  // The read that follows a move is said in a line under the header. Taking
  // the booking off the screen for it would blank a page that is still true.
  testWidgets('a booking stays on screen while the page is read again', (
    WidgetTester tester,
  ) async {
    final _Bookings bookings = _Bookings(holdsTheSecondRead: true);

    await tester.pumpWidget(_screen(bookings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(LoadingState), findsNothing);
    expect(find.text('Ana Marić'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOne);
    expect(_confirm(tester).onPressed, isNull);

    bookings.releaseTheRead();
    await tester.pump();
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  // Leaving mid-write would hand the list a row about to be wrong, and the
  // refusal a write can come back with has nowhere to be said once the dialog
  // holding it is gone. Neither way off the screen is open while one runs.
  testWidgets('a move in flight holds the screen it is written on', (
    WidgetTester tester,
  ) async {
    final _Bookings bookings = _Bookings(holdsTheWrite: true);

    await tester.pumpWidget(_screen(bookings));
    await tester.pumpAndSettle();

    expect(_back(tester).onPressed, isNotNull);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm booking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(_back(tester).onPressed, isNull);
    expect(
      find.byTooltip('The move being written has to land first.'),
      findsOne,
    );

    bookings.releaseTheWrite();
    await tester.pump();
    await tester.pump();

    expect(_back(tester).onPressed, isNotNull);
  });

  testWidgets('a cancellation being written cannot be clicked away', (
    WidgetTester tester,
  ) async {
    final _Bookings bookings = _Bookings(
      cancelFails: true,
      holdsTheWrite: true,
    );

    await tester.pumpWidget(_screen(bookings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'The host is ill.');
    await tester.tap(find.text('Cancel the booking'));
    await tester.pump();

    await tester.tapAt(const Offset(20, 20));
    await tester.pump();

    expect(find.text('Cancel this booking?'), findsOne);

    bookings.releaseTheWrite();
    await tester.pumpAndSettle();

    expect(
      find.text('A Completed reservation cannot become Cancelled.'),
      findsOne,
    );
    expect(find.text('Cancel this booking?'), findsOne);
  });

  testWidgets('a booking that could not be read empties the screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(_Bookings(bookingFails: true)));
    await tester.pumpAndSettle();

    expect(find.text('The booking could not be read.'), findsOne);
    expect(find.text('Trace 9f2c41'), findsOne);
  });
}

FilledButton _confirm(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

OutlinedButton _cancel(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.byType(OutlinedButton));

FilledButton _labelled(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

IconButton _back(WidgetTester tester) => tester.widget<IconButton>(
  find.widgetWithIcon(IconButton, Icons.arrow_back),
);

Widget _screen(_Bookings bookings, {ExperienceSlotsRepository? slots}) =>
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<ReservationsRepository>.value(value: bookings),
        Provider<ExperienceSlotsRepository>.value(value: slots ?? _Slots()),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ReservationDetailScreen(reservationId: 1)),
      ),
    );

class _Bookings extends BookingsDouble {
  _Bookings({
    Reservation? reservation,
    this.bookingFails = false,
    this.paymentFails = false,
    this.cancelFails = false,
    this.holdsTheSecondRead = false,
    this.holdsTheQuote = false,
    this.holdsTheWrite = false,
  }) : _reservation = reservation ?? booking();

  Reservation _reservation;
  final bool bookingFails;
  final bool paymentFails;
  final bool cancelFails;

  // Held open so a test can stand in the moment a call is still running.
  final bool holdsTheSecondRead;
  final bool holdsTheQuote;
  final bool holdsTheWrite;
  final Completer<void> _secondRead = Completer<void>();
  final Completer<void> _quote = Completer<void>();
  final Completer<void> _write = Completer<void>();

  final List<String> reasons = <String>[];
  int reads = 0;
  int confirms = 0;

  void releaseTheRead() => _secondRead.complete();

  void releaseTheQuote() => _quote.complete();

  void releaseTheWrite() => _write.complete();

  @override
  Future<Reservation> get(int id) async {
    reads++;

    if (holdsTheSecondRead && reads > 1) {
      await _secondRead.future;
    }

    if (bookingFails) {
      throw const ApiException(
        message: 'The booking could not be read.',
        statusCode: 500,
        traceId: '9f2c41',
      );
    }

    return _reservation;
  }

  @override
  Future<Reservation> confirm(int id) async {
    if (holdsTheWrite) {
      await _write.future;
    }

    confirms++;
    _reservation = booking(
      reservationStatusId: 2,
      status: 'Confirmed',
      isPaid: true,
    );

    return _reservation;
  }

  // The API answers a booking nobody ever paid for with a 404, which the
  // repository reads as an absence rather than a failure.
  @override
  Future<ReservationPayment?> payment(int id) async {
    if (paymentFails) {
      throw const ApiException(
        message: 'The API is not answering.',
        statusCode: 500,
      );
    }

    return null;
  }

  @override
  Future<ReservationRefund?> refund(int id) async => null;

  @override
  Future<RefundQuote> refundQuote(int id) async {
    if (holdsTheQuote) {
      await _quote.future;
    }

    return _owed(id);
  }

  static RefundQuote _owed(int id) => RefundQuote(
    reservationId: id,
    isPaid: true,
    charged: 760,
    currency: 'bam',
    percentage: 80,
    amount: 608,
    reason: 'Cancelled more than seven days before the stay begins.',
    graceEndsAt: DateTime.utc(2026, 8, 21, 9, 30),
    asOf: DateTime.utc(2026, 8, 25),
  );

  @override
  Future<Reservation> cancel(int id, {required String reason}) async {
    if (holdsTheWrite) {
      await _write.future;
    }

    if (cancelFails) {
      throw const ApiException(
        message: 'A Completed reservation cannot become Cancelled.',
        statusCode: 400,
      );
    }

    reasons.add(reason);

    return _reservation;
  }
}

class _Slots implements ExperienceSlotsRepository {
  @override
  Future<ExperienceSlot> get(int experienceId, int slotId) async =>
      ExperienceSlot(
        id: slotId,
        experienceId: experienceId,
        startTime: DateTime.utc(2026, 9, 12, 6),
        endTime: DateTime.utc(2026, 9, 12, 10),
        durationMinutes: 240,
        capacity: 12,
        remainingCapacity: 10,
        isActive: true,
      );

  @override
  Future<PagedResult<ExperienceSlot>> search(
    int experienceId, {
    required ExperienceSlotQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) => throw UnimplementedError();

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
  }) => throw UnimplementedError();

  @override
  Future<void> delete(int experienceId, int slotId) =>
      throw UnimplementedError();
}
