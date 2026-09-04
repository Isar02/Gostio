import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/widgets/date_field.dart';
import 'package:gostio_desktop/features/listings/data/listing_choice.dart';
import 'package:gostio_desktop/features/reservations/data/reservation_query.dart';
import 'package:gostio_desktop/features/reservations/presentation/reservation_filter_options.dart';
import 'package:gostio_desktop/features/reservations/presentation/reservation_filters.dart';

void main() {
  testWidgets('a listing is narrowed on the side of the catalogue it is on', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();

    await tester.pumpWidget(harness.build());
    await harness.choose(tester, 'Any listing', 'Rafting the Neretva canyon');

    expect(
      harness.announced?.listing,
      const ListingAddress(ListingKind.experience, 12),
    );
    expect(harness.announced?.toParameters(), <String, dynamic>{
      'experienceId': 12,
    });
  });

  testWidgets('a filter that did not load goes back off the controls', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();

    await tester.pumpWidget(harness.build());
    await harness.choose(tester, 'Any', 'Confirmed');

    expect(harness.announced?.reservationStatusId, 2);

    // The request failed, so the rows are still the ones the empty query
    // fetched and the notifier's query never moved.
    await harness.settle(tester, const ReservationQuery());

    expect(find.text('Confirmed'), findsNothing);
  });

  testWidgets('a filter that loaded stays on the controls', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness();

    await tester.pumpWidget(harness.build());
    await harness.choose(tester, 'Any', 'Confirmed');

    await harness.settle(tester, harness.announced!);

    expect(find.text('Confirmed'), findsOneWidget);
  });

  // A window that ends before it starts is one the API refuses, so the two
  // edges bound each other's picker rather than being sent and rejected.
  testWidgets('each edge of the window bounds the other', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness(
      applied: ReservationQuery(
        from: DateTime(2026, 9, 4),
        to: DateTime(2026, 9, 30),
      ),
    );

    await tester.pumpWidget(harness.build());

    final Iterable<DateField> days = tester.widgetList<DateField>(
      find.byType(DateField),
    );
    final DateField from = days.elementAt(0);
    final DateField to = days.elementAt(1);

    expect(from.lastDate, DateTime(2026, 9, 30));
    expect(to.firstDate, DateTime(2026, 9, 4));
  });

  testWidgets('clearing takes every filter off at once', (
    WidgetTester tester,
  ) async {
    final _Harness harness = _Harness(
      applied: ReservationQuery(
        listing: const ListingAddress(ListingKind.accommodation, 4),
        reservationStatusId: 2,
        isActive: true,
        from: DateTime(2026, 9, 4),
      ),
    );

    await tester.pumpWidget(harness.build());
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(harness.announced, const ReservationQuery());
    expect(harness.announced?.isEmpty, isTrue);
  });
}

class _Harness {
  _Harness({this.applied = const ReservationQuery()});

  static const ReservationFilterOptions options = ReservationFilterOptions(
    statuses: <LookupItem>[
      LookupItem(id: 1, name: 'Pending'),
      LookupItem(id: 2, name: 'Confirmed'),
    ],
    listings: <ListingChoice>[
      ListingChoice(
        ListingKind.accommodation,
        LookupItem(id: 4, name: 'Stone villa on the hill above Neum'),
      ),
      ListingChoice(
        ListingKind.experience,
        LookupItem(id: 12, name: 'Rafting the Neretva canyon'),
      ),
    ],
  );

  ReservationQuery applied;
  bool isLoading = false;
  ReservationQuery? announced;

  late StateSetter _rebuild;

  Widget build() => MaterialApp(
    home: Scaffold(
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          _rebuild = setState;

          return ReservationFilters(
            options: options,
            applied: applied,
            isLoading: isLoading,
            onChanged: (ReservationQuery query) => announced = query,
          );
        },
      ),
    ),
  );

  Future<void> choose(WidgetTester tester, String from, String option) async {
    await tester.tap(find.text(from).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();

    _rebuild(() => isLoading = true);
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester, ReservationQuery query) async {
    _rebuild(() {
      applied = query;
      isLoading = false;
    });
    await tester.pumpAndSettle();
  }
}
