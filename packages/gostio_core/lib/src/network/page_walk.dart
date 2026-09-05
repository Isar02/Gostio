import '../models/paged_result.dart';
import 'api_client.dart';

// A dropdown, a gallery and a filter sheet are filled from the whole table
// rather than from its first page. The API caps a page at a hundred rows, so
// the pages are walked until the count the server answered is covered.
//
// This is a fact about the contract rather than about a screen, which is why
// both clients read it from here instead of each holding the cap themselves.
Future<List<T>> readEveryPage<T>(
  ApiClient client,
  String path, {
  required T Function(JsonMap item) read,
  JsonMap? query,
}) async {
  const int pageSize = 100;
  final List<T> items = <T>[];

  for (int page = 1; ; page++) {
    final JsonMap body = await client.get(
      path,
      query: <String, dynamic>{...?query, 'page': page, 'pageSize': pageSize},
    );
    final PagedResult<T> fetched = PagedResult<T>.fromJson(
      body,
      (Object? item) => read(item! as JsonMap),
    );

    items.addAll(fetched.items);

    if (fetched.items.isEmpty || items.length >= fetched.totalCount) {
      return items;
    }
  }
}
