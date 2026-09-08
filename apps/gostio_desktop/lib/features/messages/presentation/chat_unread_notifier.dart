import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../data/chat_hub.dart';
import '../data/messages_repository.dart';

class ChatUnreadNotifier extends ScreenNotifier {
  ChatUnreadNotifier(this._messages, {ChatHub? hub}) {
    unawaited(refresh());
    _listening = hub?.watchAccount().listen((int _) => unawaited(refresh()));
    _poll = Timer.periodic(pollInterval, (Timer _) => refresh());
  }

  // The fallback for when the socket is not there.
  static const Duration pollInterval = Duration(seconds: 30);

  final MessagesRepository _messages;

  late final Timer _poll;
  StreamSubscription<int>? _listening;

  int _unread = 0;
  int _request = 0;
  ConversationType? _kind;

  int get unread => _unread;

  // The badge counts what the panel it sits in would list.
  Future<void> scopeTo(ConversationType? kind) {
    if (kind == _kind) {
      return Future<void>.value();
    }

    _kind = kind;

    return refresh();
  }

  Future<void> refresh() async {
    final int request = ++_request;

    try {
      _write(request, await _messages.unreadCount(type: _kind));
    } on ApiException {
      return;
    }
  }

  // The marking answers for the whole account, so a badge counting one kind
  // cannot take that number and asks again instead.
  void report(int unread) {
    if (_kind != null) {
      unawaited(refresh());

      return;
    }

    _write(++_request, unread);
  }

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
    unawaited(_listening?.cancel());

    super.dispose();
  }
}
