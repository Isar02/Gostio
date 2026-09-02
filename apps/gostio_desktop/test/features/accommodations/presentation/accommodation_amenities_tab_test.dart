import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/accommodations/data/accommodation_amenities_repository.dart';
import 'package:gostio_desktop/features/accommodations/presentation/accommodation_amenities_tab.dart';
import 'package:gostio_desktop/features/reference/data/lookup_item.dart';
import 'package:gostio_desktop/features/reference/data/reference_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/reference_double.dart';

void main() {
  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Amenities(failing: true)));
    await tester.pumpAndSettle();

    expect(find.text('The amenities could not be read.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Trace 3ae901'), findsOneWidget);
  });

  testWidgets('the wall marks what is offered and waits for a change', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Amenities()));
    await tester.pumpAndSettle();

    expect(find.text('2 of 4 offered'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(find.byIcon(Icons.add), findsNWidgets(2));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('turning one on says what would change and offers to save', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_tab(_Amenities()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Balcony'));
    await tester.pumpAndSettle();

    expect(find.text('3 of 4 offered · 1 to add'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('discarding puts back the set the server holds', (
    WidgetTester tester,
  ) async {
    final _Amenities offerings = _Amenities();
    await tester.pumpWidget(_tab(offerings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Balcony'));
    await tester.tap(find.text('Wi-Fi'));
    await tester.pumpAndSettle();

    expect(
      find.text('2 of 4 offered · 1 to add · 1 to remove'),
      findsOneWidget,
    );

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('2 of 4 offered'), findsOneWidget);
    expect(offerings.written, isNull);
  });

  testWidgets('a saved set is the one the server answered with', (
    WidgetTester tester,
  ) async {
    final _Amenities offerings = _Amenities();
    await tester.pumpWidget(_tab(offerings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Balcony'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save amenities'));
    await tester.pumpAndSettle();

    expect(offerings.written, <int>[1, 2, 3]);
    expect(find.text('3 of 4 offered'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}

const List<LookupItem> _vocabulary = <LookupItem>[
  LookupItem(id: 1, name: 'Wi-Fi'),
  LookupItem(id: 2, name: 'Kitchen'),
  LookupItem(id: 3, name: 'Balcony'),
  LookupItem(id: 4, name: 'Heating'),
];

Widget _tab(_Amenities offerings) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<AccommodationAmenitiesRepository>.value(value: offerings),
    Provider<ReferenceRepository>.value(value: _Reference()),
  ],
  child: const MaterialApp(
    home: Scaffold(body: AccommodationAmenitiesTab(accommodationId: 7)),
  ),
);

class _Amenities implements AccommodationAmenitiesRepository {
  _Amenities({this.failing = false});

  final bool failing;

  List<int>? written;

  List<LookupItem> rows = <LookupItem>[_vocabulary[0], _vocabulary[1]];

  @override
  Future<List<LookupItem>> forAccommodation(int accommodationId) async {
    if (failing) {
      throw const ApiException(
        message: 'The amenities could not be read.',
        statusCode: 500,
        traceId: '3ae901',
      );
    }

    return rows;
  }

  @override
  Future<List<LookupItem>> set(
    int accommodationId,
    List<int> amenityIds,
  ) async {
    written = amenityIds;
    rows = <LookupItem>[
      for (final LookupItem amenity in _vocabulary)
        if (amenityIds.contains(amenity.id)) amenity,
    ];

    return rows;
  }
}

class _Reference extends ReferenceDouble {
  @override
  Future<List<LookupItem>> amenities() async => _vocabulary;
}
