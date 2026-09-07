import '../../../core/state/live_notifier.dart';

// One write at a time across the three an account makes about itself: its
// fields, its picture and its password. Two of them overlapping is not a slow
// screen, it is a wrong one. A password that lands while a details save is in
// flight raises the account's token version, and the save already on its way is
// then answered with a 401 that ends the session — the one thing this screen
// promises does not happen. Two writes that both answer an account are the
// quieter half of it, where the later reply is the older account and puts back
// what the earlier one had just changed.
//
// On a phone the three are on three routes rather than side by side on one
// screen, so the lock is held above all of them: a form left through Back while
// it is saving is still saving, and whatever the reader opens next has to know
// that.
class ProfileWriteLock extends LiveNotifier {
  bool _isWriting = false;
  int _writes = 0;

  bool get isWriting => _isWriting;

  // How many writes have begun on this account. A read that started before one
  // of them answers what the account said before it, so the reader of a read
  // compares this figure against the one it started with rather than putting an
  // older account back over a newer write.
  int get writes => _writes;

  // Answers false without writing where another write is already out, which is
  // the same answer a refused write gives: nothing landed.
  Future<bool> holding(Future<bool> Function() write) async {
    if (_isWriting) {
      return false;
    }

    _isWriting = true;
    _writes++;
    publish();

    try {
      return await write();
    } finally {
      _isWriting = false;
      publish();
    }
  }
}
