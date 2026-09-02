import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/network/api_client.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/reference/data/reference_query.dart';
import 'package:gostio_desktop/features/reference/data/reference_row.dart';
import 'package:gostio_desktop/features/reference/data/reference_rows_repository.dart';
import 'package:gostio_desktop/features/reference/data/reference_table.dart';

// The eight tables answer the same five calls under a path of their own, so
// one stand-in serves every test here: which table was reached, what it was
// asked for and what it was told.
class ReferenceRowsDouble implements ReferenceRowsRepository {
  ReferenceRowsDouble({
    this.rows = const <ReferenceRow>[],
    int? totalCount,
    this.refusing,
    this.failing = false,
  }) : totalCount = totalCount ?? rows.length;

  final List<ReferenceRow> rows;
  final int totalCount;

  // What a write comes back with, and whether a read comes back at all.
  final ApiException? refusing;
  final bool failing;

  final List<ReferenceTable> tables = <ReferenceTable>[];
  final List<int> pages = <int>[];
  final List<ReferenceQuery> queries = <ReferenceQuery>[];
  final List<JsonMap> written = <JsonMap>[];
  final List<int> deleted = <int>[];

  @override
  Future<PagedResult<ReferenceRow>> search(
    ReferenceTable table, {
    required ReferenceQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    tables.add(table);
    pages.add(page);
    queries.add(query);

    if (failing) {
      throw const ApiException(
        message: 'The table could not be read.',
        traceId: '7c30f1',
      );
    }

    return PagedResult<ReferenceRow>(
      items: rows,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }

  @override
  Future<ReferenceRow> create(ReferenceTable table, JsonMap body) async =>
      _write(body);

  @override
  Future<ReferenceRow> update(
    ReferenceTable table,
    int id,
    JsonMap body,
  ) async => _write(body);

  @override
  Future<void> delete(ReferenceTable table, int id) async {
    if (refusing case final ApiException refused) {
      throw refused;
    }

    deleted.add(id);
  }

  ReferenceRow _write(JsonMap body) {
    if (refusing case final ApiException refused) {
      throw refused;
    }

    written.add(body);

    return ReferenceRow.fromJson(<String, dynamic>{
      ReferenceKeys.id: 1,
      ...body,
    });
  }
}
