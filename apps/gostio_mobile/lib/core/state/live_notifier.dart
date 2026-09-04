import 'package:flutter/foundation.dart';

// A call in flight outlives the screen that started it — a form left through
// Back while it is sending, a page still being fetched when the tab closes.
// What the answer wanted to announce is dropped rather than thrown at a
// notifier nobody listens to.
//
// This is the guard alone. What a screen does with a request, and what a list
// does with a page, are different contracts and are held separately above it.
abstract class LiveNotifier extends ChangeNotifier {
  bool _isDisposed = false;

  @protected
  bool get isDisposed => _isDisposed;

  @protected
  void publish() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;

    super.dispose();
  }
}
