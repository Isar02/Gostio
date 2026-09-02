import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/reference/data/reference_row.dart';
import 'package:gostio_desktop/features/reference/data/reference_table.dart';
import 'package:gostio_desktop/features/reference/presentation/reference_layout.dart';

void main() {
  test('every table asks for a name and only its own beside it', () {
    for (final ReferenceTable table in ReferenceTable.values) {
      final ReferenceLayout layout = ReferenceLayout.of(table);

      expect(
        layout.form.first.key,
        ReferenceKeys.name,
        reason: '${table.noun} does not ask for a name first',
      );
      expect(layout.form.length, layout.fields.length + 1);
    }
  });

  test('five of the eight hold nothing but a name', () {
    final Iterable<ReferenceTable> plain = ReferenceTable.values.where(
      (ReferenceTable table) => ReferenceLayout.of(table).fields.isEmpty,
    );

    expect(plain, hasLength(5));
    expect(plain, contains(ReferenceTable.amenities));
    expect(plain, contains(ReferenceTable.roles));
  });

  test('the country this platform carries keeps its code', () {
    final ReferenceLayout layout = ReferenceLayout.of(ReferenceTable.countries);
    final ReferenceRow home = _row(
      1,
      'Bosnia and Herzegovina',
      <String, dynamic>{ReferenceKeys.isoCode: 'BA'},
    );
    final ReferenceRow other = _row(2, 'Croatia', <String, dynamic>{
      ReferenceKeys.isoCode: 'HR',
    });

    expect(
      layout.frozen!(home, ReferenceKeys.isoCode),
      'Bosnia and Herzegovina is the country this platform carries, so its '
      'code cannot change.',
    );
    expect(layout.frozen!(home, ReferenceKeys.name), isNull);
    expect(layout.frozen!(other, ReferenceKeys.isoCode), isNull);
    expect(layout.kept, isNull);
  });

  // Renaming one of the three closes every endpoint naming it, so the server
  // refuses both writes and the dialog offers neither.
  test('a role the endpoints name is neither renamed nor removed', () {
    final ReferenceLayout layout = ReferenceLayout.of(ReferenceTable.roles);
    final ReferenceRow named = _row(1, 'Administrator');
    final ReferenceRow added = _row(4, 'Auditor');

    expect(
      layout.frozen!(named, ReferenceKeys.name),
      'The Administrator role is named by the endpoints themselves and can be '
      'neither renamed nor removed.',
    );
    expect(layout.kept!(named), isNotNull);
    expect(layout.frozen!(added, ReferenceKeys.name), isNull);
    expect(layout.kept!(added), isNull);
  });

  // The state machine names four by id: their code is fixed and they stay,
  // while the name and description they are read by are not.
  test('a status the state machine names keeps its code and its place', () {
    final ReferenceLayout layout = ReferenceLayout.of(
      ReferenceTable.reservationStatuses,
    );
    final ReferenceRow seeded = _row(3, 'Cancelled', <String, dynamic>{
      ReferenceKeys.code: 'Cancelled',
    });
    final ReferenceRow added = _row(5, 'Disputed', <String, dynamic>{
      ReferenceKeys.code: 'Disputed',
    });

    expect(
      layout.frozen!(seeded, ReferenceKeys.code),
      startsWith('The Cancelled status is one the reservation state machine'),
    );
    expect(layout.frozen!(seeded, ReferenceKeys.name), isNull);
    expect(layout.frozen!(seeded, ReferenceKeys.description), isNull);
    expect(layout.kept!(seeded), isNotNull);
    expect(layout.frozen!(added, ReferenceKeys.code), isNull);
    expect(layout.kept!(added), isNull);
  });

  test('a city is the only table whose dialog reads a list of its own', () {
    for (final ReferenceTable table in ReferenceTable.values) {
      expect(
        ReferenceLayout.of(table).choices,
        table == ReferenceTable.cities ? isNotNull : isNull,
        reason: '${table.noun} reads the wrong number of lists',
      );
    }
  });
}

ReferenceRow _row(int id, String name, [Map<String, dynamic>? details]) =>
    ReferenceRow.fromJson(<String, dynamic>{
      ReferenceKeys.id: id,
      ReferenceKeys.name: name,
      ...?details,
    });
