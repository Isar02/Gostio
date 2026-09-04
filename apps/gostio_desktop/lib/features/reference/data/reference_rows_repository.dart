import 'package:gostio_core/gostio_core.dart';

import 'reference_query.dart';
import 'reference_row.dart';
import 'reference_table.dart';

class ReferenceRowsRepository {
  const ReferenceRowsRepository(this._client);

  final ApiClient _client;

  Future<PagedResult<ReferenceRow>> search(
    ReferenceTable table, {
    required ReferenceQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    final JsonMap body = await _client.get(
      table.path,
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        ...query.toParameters(),
      },
    );

    return PagedResult<ReferenceRow>.fromJson(
      body,
      (Object? item) => ReferenceRow.fromJson(item! as JsonMap),
    );
  }

  Future<ReferenceRow> create(ReferenceTable table, JsonMap body) async =>
      ReferenceRow.fromJson(await _client.post(table.path, body: body));

  Future<ReferenceRow> update(
    ReferenceTable table,
    int id,
    JsonMap body,
  ) async =>
      ReferenceRow.fromJson(await _client.put('${table.path}/$id', body: body));

  Future<void> delete(ReferenceTable table, int id) =>
      _client.delete('${table.path}/$id');
}
