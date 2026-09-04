import 'package:flutter/foundation.dart';

// A call in flight outlives the screen that started it — a form left through
// Back while it is sending. What the answer wanted to announce is dropped
// rather than thrown at a notifier nobody listens to.
abstract class ScreenNotifier extends ChangeNotifier {
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
