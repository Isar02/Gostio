import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/users/data/user_draft.dart';

void main() {
  const UserDraft draft = UserDraft(
    firstName: 'Lamija',
    lastName: 'Hodžić',
    email: 'lamija.h@gostio.test',
    phoneNumber: '061 234 567',
  );

  test('an account being made carries what is only ever written once', () {
    expect(
      draft.toCreate(
        username: 'lamija.h',
        password: 'a good one',
        confirmPassword: 'a good one',
        roles: <String>['Host'],
      ),
      <String, dynamic>{
        'firstName': 'Lamija',
        'lastName': 'Hodžić',
        'email': 'lamija.h@gostio.test',
        'phoneNumber': '061 234 567',
        'username': 'lamija.h',
        'password': 'a good one',
        'confirmPassword': 'a good one',
        'roles': <String>['Host'],
      },
    );
  });

  // The username, the password and the roles are written elsewhere or not at
  // all, so an edit carries the four fields the endpoint takes and no more.
  test('an edit writes the four fields the endpoint takes', () {
    expect(draft.toUpdate().keys, <String>[
      'firstName',
      'lastName',
      'email',
      'phoneNumber',
    ]);
  });

  test('an emptied phone number is sent rather than left out', () {
    const UserDraft cleared = UserDraft(
      firstName: 'Lamija',
      lastName: 'Hodžić',
      email: 'lamija.h@gostio.test',
      phoneNumber: null,
    );

    expect(cleared.toUpdate().containsKey('phoneNumber'), isTrue);
    expect(cleared.toUpdate()['phoneNumber'], isNull);
  });
}
