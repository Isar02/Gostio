import '../../../core/state/unread_count.dart';
import '../data/messages_repository.dart';

// What is waiting in the inbox, drawn over the tab from wherever the reader
// is. It is read once for the whole client rather than once per tab, and a
// thread marked read hands it the figure the server answered.
class UnreadMessages extends UnreadCount {
  UnreadMessages(this._repository);

  final MessagesRepository _repository;

  @override
  Future<int> read() => _repository.unreadCount();
}
