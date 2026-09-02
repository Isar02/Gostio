import 'package:flutter/foundation.dart';

import '../network/api_exception.dart';
import 'paged_notifier.dart';

@immutable
class WriteOutcome {
  const WriteOutcome.written({required this.viewSettled}) : refusal = null;

  const WriteOutcome.refused(this.refusal) : viewSettled = false;

  final ApiException? refusal;
  final bool viewSettled;

  bool get wasWritten => refusal == null;
}

mixin WritingNotifier<T, TQuery> on PagedNotifier<T, TQuery> {
  bool _isWriting = false;
  bool _isStale = false;
  bool _awaitsRead = false;

  bool get isWriting => _isWriting;

  bool get isStale => _isStale;

  @override
  void onLoaded({required bool landed}) {
    if (landed) {
      _awaitsRead = false;
      _isStale = false;
    } else if (_awaitsRead) {
      _isStale = true;
    }
  }

  @protected
  Future<WriteOutcome> write(
    Future<void> Function() write, {
    Future<void> Function()? read,
  }) async {
    _isWriting = true;
    publish();

    try {
      await write();
    } on ApiException catch (refused) {
      _isWriting = false;
      publish();

      return WriteOutcome.refused(refused);
    }

    _isWriting = false;
    _awaitsRead = true;
    await (read ?? reload)();

    return WriteOutcome.written(viewSettled: !_awaitsRead && !_isStale);
  }
}
