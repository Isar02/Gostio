import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';

// The guard both clients put in front of every write that answers with an
// account or a token. What it is asked is one question — is the session that
// gets this reply still the session that asked for it.
void main() {
  // Ending a session clears the image cache, which needs the binding up.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a mark taken and read under the same session holds', () {
    final Session session = _signedIn();

    expect(SessionMark.of(session).stillHolds(session), isTrue);
  });

  test('a mark does not hold once the session has ended', () {
    final Session session = _signedIn();
    final SessionMark asked = SessionMark.of(session);

    session.end(SessionEnding.signedOut);

    expect(asked.stillHolds(session), isFalse);
  });

  // The reply of the reader who signed out, arriving into the session of the
  // reader who signed in after them.
  test('a mark does not hold for the account that came after it', () {
    final Session session = _signedIn();
    final SessionMark asked = SessionMark.of(session);

    session
      ..end(SessionEnding.signedOut)
      ..begin(account: _account(id: 33), token: 'the-second-token');

    expect(asked.stillHolds(session), isFalse);
  });

  // The same reader, whose token was replaced while the reply was in flight:
  // the account is theirs but the token it carries is one behind.
  test('a mark does not hold once the token has been replaced', () {
    final Session session = _signedIn();
    final SessionMark asked = SessionMark.of(session);

    session.tokenRenewed('a-newer-token');

    expect(asked.stillHolds(session), isFalse);
  });

  test('a mark taken while nobody was signed in holds for nothing', () {
    final Session session = Session(
      ApiClient(baseUrl: Uri.parse('http://localhost:5000')),
    );
    final SessionMark asked = SessionMark.of(session);

    session.begin(account: _account(), token: 'the-first-token');

    expect(asked.stillHolds(session), isFalse);
  });
}

Session _signedIn() =>
    Session(ApiClient(baseUrl: Uri.parse('http://localhost:5000')))
      ..begin(account: _account(), token: 'the-first-token');

User _account({int id = 7}) => User(
  id: id,
  firstName: 'Amila',
  lastName: 'Selimović',
  username: 'amila.selimovic',
  email: 'amila@gostio.test',
  phoneNumber: null,
  hasProfileImage: false,
  isActive: true,
  roles: const <String>['Guest'],
  createdAt: DateTime.utc(2026, 1, 1),
);
