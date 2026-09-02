import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/reference/data/reference_row.dart';

void main() {
  test(
    'a row of any table keeps whatever the API answered beside its name',
    () {
      final ReferenceRow row = ReferenceRow.fromJson(<String, dynamic>{
        'id': 4,
        'name': 'Konjic',
        'countryId': 1,
        'countryName': 'Bosnia and Herzegovina',
      });

      expect(row.id, 4);
      expect(row.name, 'Konjic');
      expect(row.text(ReferenceKeys.countryName), 'Bosnia and Herzegovina');
      expect(row.number(ReferenceKeys.countryId), 1);
    },
  );

  test('the name is read by its key like anything else', () {
    final ReferenceRow row = ReferenceRow.fromJson(<String, dynamic>{
      'id': 2,
      'name': 'Wi-Fi',
    });

    expect(row.text(ReferenceKeys.name), 'Wi-Fi');
    expect(row.details, isEmpty);
  });

  // A description the row does not carry reads as nothing rather than throwing
  // in a column that every table shares.
  test('a part the table does not hold reads as empty', () {
    final ReferenceRow row = ReferenceRow.fromJson(<String, dynamic>{
      'id': 3,
      'name': 'Cancelled',
      'code': 'Cancelled',
      'description': null,
    });

    expect(row.text(ReferenceKeys.code), 'Cancelled');
    expect(row.text(ReferenceKeys.description), isEmpty);
    expect(row.text(ReferenceKeys.isoCode), isEmpty);
    expect(row.number(ReferenceKeys.countryId), isNull);
  });
}
