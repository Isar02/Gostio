import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/reference/data/reference_query.dart';

void main() {
  test('a term nobody typed is left out of the request', () {
    expect(const ReferenceQuery().toParameters(), isEmpty);
    expect(const ReferenceQuery().isEmpty, isTrue);
    expect(const ReferenceQuery(name: '   ').isEmpty, isTrue);
  });

  test('a term goes out trimmed', () {
    expect(
      const ReferenceQuery(name: '  Neum ').toParameters(),
      <String, dynamic>{'name': 'Neum'},
    );
  });

  test('two queries built the same way are the same query', () {
    expect(
      const ReferenceQuery(name: 'Mostar'),
      const ReferenceQuery(name: 'Mostar'),
    );
    expect(const ReferenceQuery(name: 'Mostar'), isNot(const ReferenceQuery()));
  });
}
