import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/paging/writing_notifier.dart';
import 'package:gostio_desktop/features/reference/data/reference_row.dart';
import 'package:gostio_desktop/features/reference/data/reference_table.dart';
import 'package:gostio_desktop/features/reference/presentation/reference_layout.dart';
import 'package:gostio_desktop/features/reference/presentation/reference_row_dialog.dart';

import '../../../support/reference_fixture.dart';

void main() {
  testWidgets('a new row sends every field under the key the API binds', (
    WidgetTester tester,
  ) async {
    final _Writes writes = _Writes();
    await _show(tester, _dialog(ReferenceTable.countries, writes: writes));

    await tester.enterText(_field('Name'), '  Croatia ');
    await tester.enterText(_field('Country code'), 'HR');
    await tester.tap(find.text('Add country'));
    await tester.pumpAndSettle();

    expect(writes.bodies, <JsonMap>[
      <String, dynamic>{
        ReferenceKeys.name: 'Croatia',
        ReferenceKeys.isoCode: 'HR',
      },
    ]);
  });

  testWidgets('a row that already exists opens on what it holds', (
    WidgetTester tester,
  ) async {
    await _show(
      tester,
      _dialog(
        ReferenceTable.reservationStatuses,
        row: referenceRow(5, 'Disputed', <String, dynamic>{
          ReferenceKeys.code: 'Disputed',
          ReferenceKeys.description: 'A guest has raised a dispute.',
        }),
      ),
    );

    expect(find.text('Disputed'), findsAtLeast(2));
    expect(find.text('A guest has raised a dispute.'), findsOneWidget);
    expect(find.text('Save reservation status'), findsOneWidget);
  });

  testWidgets('a refused write keeps the dialog and faults the field', (
    WidgetTester tester,
  ) async {
    final _Writes writes = _Writes(
      refusing: const ApiException(
        message: 'The request could not be completed.',
        statusCode: 400,
        errors: <String, List<String>>{
          'Name': <String>['Another country already goes by this name.'],
        },
      ),
    );
    await _show(tester, _dialog(ReferenceTable.countries, writes: writes));

    await tester.enterText(_field('Name'), 'Croatia');
    await tester.enterText(_field('Country code'), 'HR');
    await tester.tap(find.text('Add country'));
    await tester.pumpAndSettle();

    expect(find.text('New country'), findsOneWidget);
    expect(
      find.text('Another country already goes by this name.'),
      findsOneWidget,
    );
    expect(find.text('The request could not be completed.'), findsNothing);
  });

  // Renaming one of the three closes every endpoint naming it, so the server
  // refuses every write on it and the dialog offers none.
  testWidgets('a role the endpoints name is read and not written', (
    WidgetTester tester,
  ) async {
    await _show(
      tester,
      _dialog(ReferenceTable.roles, row: referenceRow(1, 'Administrator')),
    );

    expect(find.text('Save role'), findsNothing);
    expect(find.text('Close'), findsOneWidget);
    expect(_deleteButton(tester).onPressed, isNull);
    expect(
      find.textContaining('named by the endpoints themselves'),
      findsWidgets,
    );
  });

  // The state machine names a status by its code and nothing reads it by its
  // name, so the one is fixed here and the other is not.
  testWidgets('a seeded status keeps its code and still takes a name', (
    WidgetTester tester,
  ) async {
    final _Writes writes = _Writes();
    await _show(
      tester,
      _dialog(
        ReferenceTable.reservationStatuses,
        writes: writes,
        row: referenceRow(3, 'Cancelled', <String, dynamic>{
          ReferenceKeys.code: 'Cancelled',
        }),
      ),
    );

    expect(_deleteButton(tester).onPressed, isNull);
    expect(tester.widget<TextFormField>(_field('Code')).enabled, isFalse);

    await tester.enterText(_field('Name'), 'Called off');
    await tester.tap(find.text('Save reservation status'));
    await tester.pumpAndSettle();

    expect(writes.bodies.single[ReferenceKeys.name], 'Called off');
    expect(writes.bodies.single[ReferenceKeys.code], 'Cancelled');
  });

  testWidgets('deleting the home country remains the server decision', (
    WidgetTester tester,
  ) async {
    await _show(
      tester,
      _dialog(
        ReferenceTable.countries,
        row: referenceRow(1, 'Bosnia and Herzegovina', <String, dynamic>{
          ReferenceKeys.isoCode: 'BA',
        }),
      ),
    );

    expect(_deleteButton(tester).onPressed, isNotNull);
    expect(
      tester.widget<TextFormField>(_field('Country code')).enabled,
      isFalse,
    );
  });

  testWidgets('a city is given the one country there is to be in', (
    WidgetTester tester,
  ) async {
    final _Writes writes = _Writes();
    await _show(
      tester,
      _dialog(
        ReferenceTable.cities,
        writes: writes,
        choices: <LookupItem>[_bosnia],
      ),
    );

    await tester.enterText(_field('Name'), 'Jajce');
    await tester.tap(find.text('Add city'));
    await tester.pumpAndSettle();

    expect(writes.bodies, <JsonMap>[
      <String, dynamic>{
        ReferenceKeys.name: 'Jajce',
        ReferenceKeys.countryId: 1,
      },
    ]);
  });

  // The server keys this refusal to the same field, so it is made here first
  // rather than sent to be answered with a 400.
  testWidgets('a city with no country chosen is refused before the write', (
    WidgetTester tester,
  ) async {
    final _Writes writes = _Writes();
    await _show(
      tester,
      _dialog(
        ReferenceTable.cities,
        writes: writes,
        choices: <LookupItem>[
          _bosnia,
          const LookupItem(id: 2, name: 'Croatia'),
        ],
      ),
    );

    await tester.enterText(_field('Name'), 'Jajce');
    await tester.tap(find.text('Add city'));
    await tester.pumpAndSettle();

    expect(writes.bodies, isEmpty);
    expect(find.text('Choose the country this city is in.'), findsOneWidget);
  });

  testWidgets('a row is deleted only once the question has been answered', (
    WidgetTester tester,
  ) async {
    final _Writes writes = _Writes();
    await _show(
      tester,
      _dialog(
        ReferenceTable.amenities,
        writes: writes,
        row: referenceRow(2, 'Balcony'),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this amenity?'), findsOneWidget);
    expect(writes.removals, 0);

    await tester.tap(find.text('Delete amenity'));
    await tester.pumpAndSettle();

    expect(writes.removals, 1);
  });
}

const LookupItem _bosnia = LookupItem(id: 1, name: 'Bosnia and Herzegovina');

Finder _field(String label) => find.widgetWithText(TextFormField, label);

TextButton _deleteButton(WidgetTester tester) =>
    tester.widget<TextButton>(find.widgetWithText(TextButton, 'Delete'));

Widget _dialog(
  ReferenceTable table, {
  _Writes? writes,
  ReferenceRow? row,
  List<LookupItem> choices = const <LookupItem>[],
}) {
  final _Writes recorded = writes ?? _Writes();

  return ReferenceRowDialog(
    noun: table.noun,
    layout: ReferenceLayout.of(table),
    row: row,
    choices: choices,
    save: recorded.save,
    remove: recorded.remove,
  );
}

// The dialog is opened over a route of its own, so that closing it pops the
// route it stands on the way it does in the screen.
Future<void> _show(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (BuildContext context) => dialog,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

class _Writes {
  _Writes({this.refusing});

  final ApiException? refusing;
  final List<JsonMap> bodies = <JsonMap>[];

  int removals = 0;

  Future<WriteOutcome> save(JsonMap body) async {
    if (refusing case final ApiException refused) {
      return WriteOutcome.refused(refused);
    }

    bodies.add(body);

    return const WriteOutcome.written(viewSettled: true);
  }

  Future<WriteOutcome> remove() async {
    if (refusing case final ApiException refused) {
      return WriteOutcome.refused(refused);
    }

    removals++;

    return const WriteOutcome.written(viewSettled: true);
  }
}
