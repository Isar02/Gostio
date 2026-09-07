import 'package:gostio_core/gostio_core.dart';

// The messages a thread has learned, independent of how they arrived. It owns
// the API's newest-first paging, stable ordering and deduplication so the
// notifier only coordinates reads and writes around this state.
class ThreadHistory {
  final List<Message> _lines = <Message>[];
  final Set<int> _held = <int>{};

  int _pagesRead = 0;
  int _totalCount = 0;

  List<Message> get lines => _lines;

  bool get hasEarlier => _lines.length < _totalCount;

  int get nextPage => _pagesRead + 1;

  List<Message> addPage(PagedResult<Message> page) {
    final List<Message> added = _merge(page.items);
    _totalCount = page.totalCount;
    if (page.page > _pagesRead) {
      _pagesRead = page.page;
    }

    return added;
  }

  List<Message> refresh(PagedResult<Message> page) {
    final List<Message> added = _merge(page.items);
    if (page.totalCount > _totalCount) {
      _totalCount = page.totalCount;
    }

    return added;
  }

  bool add(Message message) {
    if (!_held.add(message.id)) {
      return false;
    }

    var at = 0;
    while (at < _lines.length && _isAfter(_lines[at], message)) {
      at++;
    }

    _lines.insert(at, message);

    // A line newer than everything already read was not counted when the
    // first page was answered. Page merges replace or reconcile the total
    // afterwards; a hub delivery keeps it correct immediately.
    if (at == 0 && _pagesRead > 0) {
      _totalCount++;
    }

    return true;
  }

  List<Message> _merge(Iterable<Message> messages) => <Message>[
    for (final Message message in messages)
      if (add(message)) message,
  ];

  static bool _isAfter(Message one, Message other) =>
      one.sentAt.isAfter(other.sentAt) ||
      (one.sentAt == other.sentAt && one.id > other.id);
}
