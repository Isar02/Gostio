import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/widgets/filter_bar.dart';
import 'package:gostio_desktop/features/reference/data/reference_query.dart';
import 'package:gostio_desktop/features/reference/data/reference_repository.dart';
import 'package:gostio_desktop/features/reference/data/reference_row.dart';
import 'package:gostio_desktop/features/reference/data/reference_rows_repository.dart';
import 'package:gostio_desktop/features/reference/data/reference_table.dart';
import 'package:gostio_desktop/features/reference/presentation/reference_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/reference_double.dart';
import '../../../support/reference_fixture.dart';
import '../../../support/reference_rows_double.dart';

void main() {
  testWidgets('a table draws the name and whatever else it holds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        ReferenceTable.reservationStatuses,
        rows: ReferenceRowsDouble(
          rows: <ReferenceRow>[
            referenceRow(2, 'Confirmed', <String, dynamic>{
              ReferenceKeys.code: 'Confirmed',
              ReferenceKeys.description: 'The host has taken the booking.',
            }),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Name'), findsWidgets);
    expect(find.text('Code'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('The host has taken the booking.'), findsOneWidget);
    expect(find.text('New reservation status'), findsOneWidget);
  });

  // A description no status carries is a cell with nothing in it, which reads
  // as a dash rather than as a column that failed to draw.
  testWidgets('a part the row does not hold reads as a dash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        ReferenceTable.reservationStatuses,
        rows: ReferenceRowsDouble(
          rows: <ReferenceRow>[
            referenceRow(4, 'Completed', <String, dynamic>{
              ReferenceKeys.code: 'Completed',
              ReferenceKeys.description: null,
            }),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('a table with nothing in it names itself as the reason', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(ReferenceTable.amenities));
    await tester.pumpAndSettle();

    expect(find.text('No amenities'), findsOneWidget);
  });

  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        ReferenceTable.amenities,
        rows: ReferenceRowsDouble(failing: true),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The table could not be read.'), findsOneWidget);
    expect(find.text('Trace 7c30f1'), findsOneWidget);
  });

  testWidgets('a term is sent to the table it was typed over', (
    WidgetTester tester,
  ) async {
    final ReferenceRowsDouble rows = ReferenceRowsDouble(
      rows: <ReferenceRow>[referenceRow(1, 'Wi-Fi')],
    );
    await tester.pumpWidget(_screen(ReferenceTable.amenities, rows: rows));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Balcony');
    await tester.pump(FilterTextField.settle);
    await tester.pumpAndSettle();

    expect(rows.tables, everyElement(ReferenceTable.amenities));
    expect(rows.queries.last.toParameters(), <String, dynamic>{
      'name': 'Balcony',
    });
  });

  // A city is placed in a country, so a country list that did not arrive
  // leaves nothing to choose and no city can be written at all.
  testWidgets('a choice list that failed shuts writing and says why', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(ReferenceTable.cities, reference: const _NoCountries()),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('The country list could not be read'),
      findsOneWidget,
    );
    expect(_newButton(tester).onPressed, isNull);
  });

  // A create lands wherever the server's order puts it, so the list is taken
  // to the row rather than read again where it was.
  testWidgets('a row that was created is the row the list then shows', (
    WidgetTester tester,
  ) async {
    final ReferenceRowsDouble rows = ReferenceRowsDouble(
      rows: <ReferenceRow>[referenceRow(1, 'Wi-Fi')],
      totalCount: 60,
    );
    await tester.pumpWidget(_screen(ReferenceTable.amenities, rows: rows));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New amenity'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Sauna');
    await tester.tap(find.text('Add amenity'));
    await tester.pumpAndSettle();

    expect(rows.queries.last.toParameters(), isEmpty);
    expect(rows.pages.last, 1);
    expect(find.text('Sauna'), findsWidgets);
    expect(find.text('Sauna was created.'), findsOneWidget);
  });

  // The write landed and the read after it did not, so the rows on screen are
  // behind the server and nothing more is written from them.
  testWidgets('a write whose read failed shuts the table and says so', (
    WidgetTester tester,
  ) async {
    final _ReadsOnce rows = _ReadsOnce(
      rows: <ReferenceRow>[referenceRow(2, 'Balcony')],
    );
    await tester.pumpWidget(_screen(ReferenceTable.amenities, rows: rows));
    await tester.pumpAndSettle();

    await _openTheRow(tester, 'Balcony');
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete amenity'));
    await tester.pumpAndSettle();

    expect(rows.deleted, <int>[2]);
    expect(
      find.textContaining('could not be read again afterwards'),
      findsOneWidget,
    );
    expect(
      find.text('Balcony was deleted. The table could not be read again.'),
      findsOneWidget,
    );
    expect(_newButton(tester).onPressed, isNull);

    await _openTheRow(tester, 'Balcony');

    expect(find.text('Save amenity'), findsNothing);
  });

  testWidgets('a row opens on a double click and is written from there', (
    WidgetTester tester,
  ) async {
    final ReferenceRowsDouble rows = ReferenceRowsDouble(
      rows: <ReferenceRow>[referenceRow(2, 'Balcony')],
    );
    await tester.pumpWidget(_screen(ReferenceTable.amenities, rows: rows));
    await tester.pumpAndSettle();

    await _openTheRow(tester, 'Balcony');

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Terrace',
    );
    await tester.tap(find.text('Save amenity'));
    await tester.pumpAndSettle();

    expect(rows.written, <Map<String, dynamic>>[
      <String, dynamic>{ReferenceKeys.name: 'Terrace'},
    ]);
  });
}

FilledButton _newButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.ancestor(
    of: find.textContaining('New '),
    matching: find.byType(FilledButton),
  ),
);

Widget _screen(
  ReferenceTable table, {
  ReferenceRowsDouble? rows,
  ReferenceRepository reference = const ReferenceDouble(),
}) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<ReferenceRepository>.value(value: reference),
    Provider<ReferenceRowsRepository>.value(
      value: rows ?? ReferenceRowsDouble(),
    ),
  ],
  child: MaterialApp(
    home: Scaffold(body: ReferenceScreen(table: table)),
  ),
);

Future<void> _openTheRow(WidgetTester tester, String name) async {
  final Finder row = find.text(name).first;

  await tester.tap(row);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(row);
  await tester.pumpAndSettle();
}

// The read after the write fails, which is what leaves the rows behind the
// server.
class _ReadsOnce extends ReferenceRowsDouble {
  _ReadsOnce({required super.rows});

  @override
  Future<PagedResult<ReferenceRow>> search(
    ReferenceTable table, {
    required ReferenceQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) {
    if (pages.isEmpty) {
      return super.search(table, query: query, page: page, pageSize: pageSize);
    }

    pages.add(page);

    throw const ApiException(message: 'The table could not be read.');
  }
}

class _NoCountries extends ReferenceDouble {
  const _NoCountries();

  @override
  Future<List<LookupItem>> countriesHoldingCities() =>
      Future<List<LookupItem>>.error(
        const ApiException(message: 'Nothing answered.'),
      );
}
