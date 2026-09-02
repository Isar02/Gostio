import '../../../core/models/image_upload.dart';
import '../../../core/models/paged_result.dart';
import '../../../core/network/api_client.dart';
import 'news_draft.dart';
import 'news_item.dart';
import 'news_query.dart';

class NewsRepository {
  const NewsRepository(this._client);

  static const String fileField = 'File';

  final ApiClient _client;

  Future<PagedResult<NewsItem>> search({
    required NewsQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    final JsonMap body = await _client.get(
      _root,
      query: <String, dynamic>{
        'page': page,
        'pageSize': pageSize,
        ...query.toParameters(),
      },
    );

    return PagedResult<NewsItem>.fromJson(
      body,
      (Object? item) => NewsItem.fromJson(item! as JsonMap),
    );
  }

  Future<NewsItem> get(int id) async =>
      NewsItem.fromJson(await _client.get('$_root/$id'));

  // The API refuses an article written without a file.
  Future<NewsItem> create(NewsDraft draft, ImageUpload image) async =>
      NewsItem.fromJson(
        await _client.postForm(
          _root,
          fields: draft.fields,
          file: image.underField(fileField),
        ),
      );

  // A picture left out leaves the stored one where it is.
  Future<NewsItem> update(
    int id,
    NewsDraft draft, {
    ImageUpload? image,
  }) async => NewsItem.fromJson(
    await _client.putForm(
      '$_root/$id',
      fields: draft.fields,
      file: image?.underField(fileField),
    ),
  );

  Future<void> delete(int id) => _client.delete('$_root/$id');

  static const String _root = '/news';
}
