import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/paging/writing_notifier.dart';
import 'package:gostio_desktop/features/reference/data/reference_query.dart';
import 'package:gostio_desktop/features/reference/data/reference_row.dart';
import 'package:gostio_desktop/features/reference/data/reference_table.dart';
import 'package:gostio_desktop/features/reference/presentation/reference_notifier.dart';

import '../../../support/reference_fixture.dart';
import '../../../support/reference_rows_double.dart';

void main() {
  test('a table is read under its own path and nothing else is', () async {
    final ReferenceRowsDouble rows = _rows();
    final ReferenceNotifier notifier = _notifier(
      rows,
      table: ReferenceTable.amenities,
    );

    await notifier.reload();

    expect(rows.tables, <ReferenceTable>[ReferenceTable.amenities]);
    expect(notifier.items.single.name, 'Sarajevo');
  });

  test('a term is applied from the first page', () async {
    final ReferenceRowsDouble rows = _rows(totalCount: 60);
    final ReferenceNotifier notifier = _notifier(rows);

    await notifier.openPage(3);
    await notifier.apply(const ReferenceQuery(name: 'Neum'));

    expect(notifier.page, 1);
    expect(rows.pages, <int>[3, 1]);
    expect(rows.queries.last.toParameters(), <String, dynamic>{'name': 'Neum'});
  });

  test('a created row becomes the focused first row', () async {
    final ReferenceRowsDouble rows = _rows();
    final ReferenceNotifier notifier = _notifier(rows);

    await notifier.reload();
    final WriteOutcome outcome = await notifier.add(<String, dynamic>{
      ReferenceKeys.name: 'Bihać',
    });

    expect(outcome.wasWritten, isTrue);
    expect(outcome.viewSettled, isTrue);
    expect(rows.written, <Map<String, dynamic>>[
      <String, dynamic>{ReferenceKeys.name: 'Bihać'},
    ]);
    expect(rows.pages, hasLength(1));
    expect(notifier.page, 1);
    expect(notifier.items.single.name, 'Bihać');
    expect(notifier.query.focusId, notifier.items.single.id);
    expect(notifier.isWriting, isFalse);
  });

  // The dialog is what stays open and says so, so the refusal is handed back
  // rather than left on the list, and the rows are not read again for it.
  test('a refused write comes back to the caller and reads nothing', () async {
    final ReferenceRowsDouble rows = _rows(
      refusing: const ApiException(
        message: 'This country already has a city by this name.',
        statusCode: 400,
      ),
    );
    final ReferenceNotifier notifier = _notifier(rows);

    await notifier.reload();
    final WriteOutcome outcome = await notifier.remove(4);

    expect(
      outcome.refusal?.message,
      'This country already has a city by this name.',
    );
    expect(rows.deleted, isEmpty);
    expect(rows.pages, hasLength(1));
    expect(notifier.failureMessage, isNull);
    expect(notifier.isWriting, isFalse);
    expect(notifier.isStale, isFalse);
  });

  // The row was written and the read after it was not, so the rows on screen
  // are behind the server until a read lands.
  test('a write whose read failed leaves the rows behind the server', () async {
    final _ReadsOnce rows = _ReadsOnce();
    final ReferenceNotifier notifier = _notifier(rows);

    await notifier.reload();
    final WriteOutcome outcome = await notifier.remove(1);

    expect(outcome.wasWritten, isTrue);
    expect(outcome.viewSettled, isFalse);
    expect(notifier.isStale, isTrue);
    expect(notifier.failureMessage, 'The table could not be read.');

    rows.answers = true;
    await notifier.reload();

    expect(notifier.isStale, isFalse);
  });
}

class _ReadsOnce extends ReferenceRowsDouble {
  _ReadsOnce() : super(rows: <ReferenceRow>[referenceRow(1, 'Sarajevo')]);

  bool answers = true;

  @override
  Future<PagedResult<ReferenceRow>> search(
    ReferenceTable table, {
    required ReferenceQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) {
    if (answers) {
      answers = false;

      return super.search(table, query: query, page: page, pageSize: pageSize);
    }

    throw const ApiException(message: 'The table could not be read.');
  }
}

ReferenceRowsDouble _rows({int? totalCount, ApiException? refusing}) =>
    ReferenceRowsDouble(
      rows: <ReferenceRow>[referenceRow(1, 'Sarajevo')],
      totalCount: totalCount,
      refusing: refusing,
    );

ReferenceNotifier _notifier(
  ReferenceRowsDouble rows, {
  ReferenceTable table = ReferenceTable.cities,
}) {
  final ReferenceNotifier notifier = ReferenceNotifier(rows, table: table);
  addTearDown(notifier.dispose);

  return notifier;
}
