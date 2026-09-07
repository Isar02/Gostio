import 'package:gostio_core/gostio_core.dart';

// Who the session was when a request left it.
//
// A reply belongs to the session that asked for it. This phone can be signed
// out and signed in as somebody else while a call is in flight, and the answer
// to the first reader's question would then be written into the second
// reader's session: their profile replaced by an account that is not theirs,
// or — worse, because nothing on the screen would say so — the first reader's
// replacement token adopted as the second reader's own.
//
// Every write in this feature therefore reads the session twice: once as it
// asks, and once before it applies what came back.
class SessionMark {
  SessionMark.of(Session session)
    : _generation = session.tokenGeneration,
      _accountId = session.account?.id;

  final int _generation;
  final int? _accountId;

  // The generation moves whenever this client's token does, which covers a
  // session that ended as much as one that began. The id is what says the same
  // account is still the one signed in, and a mark taken while nobody was
  // holds for nothing.
  bool stillHolds(Session session) =>
      _accountId != null &&
      session.tokenGeneration == _generation &&
      session.account?.id == _accountId;
}
