import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/widgets/app_dropdown.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_availability_repository.dart';
import 'package:gostio_desktop/features/accommodations/data/availability_draft.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_availability_tab.dart';
import 'package:gostio_desktop/features/accommodations/presentation/availability_entry_dialog.dart';
import 'package:gostio_desktop/features/reservations/data/reservations_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/bookings_double.dart';

void main() {
  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Availability(failing: true)));
    await tester.pumpAndSettle();

    expect(find.text('The calendar could not be read.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Trace 62b0d4'), findsOneWidget);
  });

  testWidgets('a month with nothing on it says every night is open', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _tab(_Availability(), bookings: const <Reservation>[]),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Every night this month is open at the listing price.'),
      findsOneWidget,
    );
    expect(find.textContaining('Click a day to write over it'), findsOneWidget);
    expect(find.text('Add entry'), findsNothing);
  });

  testWidgets('a day carrying an entry opens it with what it says', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _tab(_Availability(rows: <AccommodationAvailability>[_blocked])),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Nights this month: 1 booked · 3 blocked'),
      findsOneWidget,
    );
    expect(find.textContaining('Ana Marić'), findsWidgets);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Blocked · '), findsOneWidget);
    expect(find.text('Remove entry'), findsOneWidget);
    expect(find.text('Add entry'), findsNothing);
  });

  testWidgets('a span reaching over an entry is refused before the write', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _tab(_Availability(rows: <AccommodationAvailability>[_blocked])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('13'));
    await tester.tap(find.text('17'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('These dates already carry an entry'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('a span over free days offers the entry it would write', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _tab(_Availability(rows: <AccommodationAvailability>[_blocked])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('18'));
    await tester.tap(find.text('20'));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 nights · '), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  // The dialog says so before the write rather than offering a button the
  // server will turn down.
  testWidgets('blocking a booked night is refused on the dialog itself', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Availability()));
    await tester.pumpAndSettle();

    await _openTheDialogOver(tester, day: '21');

    expect(find.textContaining('1 of these nights is booked'), findsOneWidget);
    expect(
      find.textContaining('Closing them cancels those bookings'),
      findsOneWidget,
    );
    expect(_dialogButton(tester).onPressed, isNull);
  });

  // The same nights may still be repriced.
  testWidgets('the same night may still be repriced', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Availability()));
    await tester.pumpAndSettle();

    await _openTheDialogOver(tester, day: '21');

    await tester.tap(
      find.descendant(
        of: find.byType(AvailabilityEntryDialog),
        matching: find.byType(AppDropdown<bool>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open, at a price of their own').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('does not move or cancel a booking'),
      findsOneWidget,
    );
    expect(_dialogButton(tester).onPressed, isNotNull);
  });

  // Nothing is holding these nights, so blocking them is the ordinary write.
  testWidgets('blocking free nights is offered as before', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Availability()));
    await tester.pumpAndSettle();

    await _openTheDialogOver(tester, day: '18');

    expect(
      find.descendant(
        of: find.byType(AvailabilityEntryDialog),
        matching: find.textContaining('booked'),
      ),
      findsNothing,
    );
    expect(_dialogButton(tester).onPressed, isNotNull);
  });
}

// The single day chosen on the calendar, opened as the entry it would write.
Future<void> _openTheDialogOver(
  WidgetTester tester, {
  required String day,
}) async {
  await tester.tap(find.text(day));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Add entry'));
  await tester.pumpAndSettle();
}

// The tab holds an *Add entry* of its own behind the dialog.
FilledButton _dialogButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.descendant(
    of: find.byType(AvailabilityEntryDialog),
    matching: find.byType(FilledButton),
  ),
);

// Days of the month on screen that no neighbouring month can also draw: the
// grid carries at most six days before it and twelve after.
DateTime _on(int day) =>
    DateTime(CalendarDays.today().year, CalendarDays.today().month, day);

final AccommodationAvailability _blocked = AccommodationAvailability(
  id: 1,
  accommodationId: 7,
  startDate: _on(14),
  endDate: _on(16),
  isAvailable: false,
);

final Reservation _booking = Reservation(
  id: 1,
  userId: 21,
  guestName: 'Ana Marić',
  listingTitle: 'Stone villa on the hill above Neum',
  guestCount: 2,
  reservationStatusId: 2,
  status: 'Confirmed',
  totalPrice: 360,
  isPaid: true,
  expiresAt: DateTime.utc(2026, 9),
  createdAt: DateTime.utc(2026, 8, 20),
  checkInDate: _on(21),
  checkOutDate: _on(22),
);

Widget _tab(
  _Availability availability, {
  List<Reservation>? bookings,
}) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<AccommodationAvailabilityRepository>.value(value: availability),
    Provider<ReservationsRepository>.value(
      value: _Reservations(bookings ?? <Reservation>[_booking]),
    ),
  ],
  child: const MaterialApp(
    home: Scaffold(
      body: AccommodationAvailabilityTab(accommodationId: 7, nightlyPrice: 120),
    ),
  ),
);

class _Availability implements AccommodationAvailabilityRepository {
  _Availability({
    this.failing = false,
    this.rows = const <AccommodationAvailability>[],
  });

  final bool failing;
  final List<AccommodationAvailability> rows;

  @override
  Future<List<AccommodationAvailability>> forWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) async {
    if (failing) {
      throw const ApiException(
        message: 'The calendar could not be read.',
        statusCode: 500,
        traceId: '62b0d4',
      );
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

class _Reservations extends BookingsDouble {
  const _Reservations(this.rows);

  final List<Reservation> rows;

  @override
  Future<List<Reservation>> forAccommodationWindow(
    int accommodationId, {
    required DateTime from,
    required DateTime to,
  }) async => rows;
}
