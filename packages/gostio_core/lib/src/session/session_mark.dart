import 'session.dart';

// Who the session was when a request left it. A client can be signed out and
// signed in as somebody else while a call is in flight, and the first reader's
// account or replacement token would then be written into the second reader's
// session. So every such write reads the session twice.
class SessionMark {
  SessionMark.of(Session session)
    : _generation = session.tokenGeneration,
      _accountId = session.account?.id;

  final int _generation;
  final int? _accountId;

  // The generation moves whenever the token does; the id says the same account
  // is still signed in. A mark taken while nobody was holds for nothing.
  bool stillHolds(Session session) =>
      _accountId != null &&
      session.tokenGeneration == _generation &&
      session.account?.id == _accountId;
}
