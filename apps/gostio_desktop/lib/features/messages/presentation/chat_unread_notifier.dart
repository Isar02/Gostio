import 'dart:async';

import '../../../core/network/api_exception.dart';
import '../../../core/state/screen_notifier.dart';
import '../data/messages_repository.dart';

class ChatUnreadNotifier extends ScreenNotifier {
  ChatUnreadNotifier(this._messages) {
    unawaited(refresh());
    _poll = Timer.periodic(pollInterval, (Timer _) => refresh());
  }

  static const Duration pollInterval = Duration(seconds: 30);

  final MessagesRepository _messages;

  late final Timer _poll;

  int _unread = 0;
  int _request = 0;

  int get unread => _unread;

  Future<void> refresh() async {
    final int request = ++_request;

    try {
      _write(request, await _messages.unreadCount());
    } on ApiException {
      return;
    }
  }

  void report(int unread) => _write(++_request, unread);

  // Several callers ask for this, so only the newest may write it.
  void _write(int request, int unread) {
    if (request == _request && unread != _unread) {
      _unread = unread;
      publish();
    }
  }

  @override
  void dispose() {
    _poll.cancel();

    super.dispose();
  }
}
