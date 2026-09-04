import 'package:gostio_core/gostio_core.dart';

import '../../../core/paging/paged_notifier.dart';
import '../../../core/paging/writing_notifier.dart';
import '../data/reference_query.dart';
import '../data/reference_row.dart';
import '../data/reference_rows_repository.dart';
import '../data/reference_table.dart';

class ReferenceNotifier extends PagedNotifier<ReferenceRow, ReferenceQuery>
    with WritingNotifier<ReferenceRow, ReferenceQuery> {
  ReferenceNotifier(this._rows, {required this.table})
    : super(const ReferenceQuery());

  final ReferenceRowsRepository _rows;

  final ReferenceTable table;
  ReferenceRow? _focused;

  @override
  Future<PagedResult<ReferenceRow>> fetch({
    required int page,
    required ReferenceQuery query,
  }) {
    if (_focused case final ReferenceRow row
        when query.focusId == row.id && page == 1) {
      return Future<PagedResult<ReferenceRow>>.value(
        PagedResult<ReferenceRow>(
          items: <ReferenceRow>[row],
          page: 1,
          pageSize: pageSize,
          totalCount: 1,
        ),
      );
    }

    _focused = null;

    return _rows.search(table, query: query, page: page, pageSize: pageSize);
  }

  Future<WriteOutcome> add(JsonMap body) =>
      _writeAndFocus(() => _rows.create(table, body));

  Future<WriteOutcome> save(int id, JsonMap body) =>
      _writeAndFocus(() => _rows.update(table, id, body));

  Future<WriteOutcome> remove(int id) => write(() => _rows.delete(table, id));

  Future<WriteOutcome> _writeAndFocus(
    Future<ReferenceRow> Function() writeRow,
  ) {
    ReferenceRow? written;

    return write(
      () async {
        written = await writeRow();
      },
      read: () {
        final ReferenceRow row = written!;
        _focused = row;

        return apply(ReferenceQuery(name: row.name, focusId: row.id));
      },
    );
  }
}
