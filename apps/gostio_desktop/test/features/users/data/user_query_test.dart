import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/users/data/user_query.dart';

void main() {
  test('a filter nobody set is left out of the request', () {
    expect(const UserQuery().toParameters(), isEmpty);
    expect(const UserQuery().isEmpty, isTrue);
  });

  // A blank box is a filter nobody set, and sending it would ask the API to
  // match on nothing.
  test('a field holding only spaces is not a value to match', () {
    expect(const UserQuery(name: '   ', username: '').toParameters(), isEmpty);
  });

  test('what was typed goes out trimmed, and the role by its name', () {
    expect(
      const UserQuery(
        name: '  Marko ',
        role: 'Host',
        isActive: false,
      ).toParameters(),
      <String, dynamic>{'name': 'Marko', 'role': 'Host', 'isActive': false},
    );
  });

  test('two queries built the same way are the same query', () {
    expect(
      const UserQuery(email: 'gostio', isActive: true),
      const UserQuery(email: 'gostio', isActive: true),
    );
    expect(
      const UserQuery(email: 'gostio'),
      isNot(const UserQuery(email: 'gostio', isActive: true)),
    );
  });
}
