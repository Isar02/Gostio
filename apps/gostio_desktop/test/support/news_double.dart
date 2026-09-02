import 'package:gostio_desktop/core/models/image_upload.dart';
import 'package:gostio_desktop/core/models/paged_result.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/news/data/news_draft.dart';
import 'package:gostio_desktop/features/news/data/news_item.dart';
import 'package:gostio_desktop/features/news/data/news_query.dart';
import 'package:gostio_desktop/features/news/data/news_repository.dart';

import 'news_fixture.dart';

// What the API was asked for and what it was told: an article is read, written
// with its picture, corrected and deleted.
class NewsDouble implements NewsRepository {
  NewsDouble({
    this.rows = const <NewsItem>[],
    int? totalCount,
    this.stored,
    this.refusing,
    this.failing = false,
  }) : totalCount = totalCount ?? rows.length;

  final List<NewsItem> rows;
  final int totalCount;

  // The one an id is read back as, and what a write comes back with.
  final NewsItem? stored;
  final ApiException? refusing;
  final bool failing;

  final List<int> pages = <int>[];
  final List<NewsQuery> queries = <NewsQuery>[];
  final List<NewsDraft> written = <NewsDraft>[];
  final List<ImageUpload?> pictures = <ImageUpload?>[];
  final List<int> deleted = <int>[];

  @override
  Future<PagedResult<NewsItem>> search({
    required NewsQuery query,
    int page = 1,
    int pageSize = PagedResult.defaultPageSize,
  }) async {
    pages.add(page);
    queries.add(query);

    if (failing) {
      throw const ApiException(
        message: 'The articles could not be read.',
        traceId: 'a17f20',
      );
    }

    return PagedResult<NewsItem>(
      items: rows,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
    );
  }

  @override
  Future<NewsItem> get(int id) async {
    if (failing) {
      throw const ApiException(message: 'The article could not be read.');
    }

    return stored ?? newsItem(id: id);
  }

  @override
  Future<NewsItem> create(NewsDraft draft, ImageUpload image) async =>
      _write(draft, image);

  @override
  Future<NewsItem> update(
    int id,
    NewsDraft draft, {
    ImageUpload? image,
  }) async => _write(draft, image);

  @override
  Future<void> delete(int id) async {
    if (refusing case final ApiException refused) {
      throw refused;
    }

    deleted.add(id);
  }

  NewsItem _write(NewsDraft draft, ImageUpload? image) {
    if (refusing case final ApiException refused) {
      throw refused;
    }

    written.add(draft);
    pictures.add(image);

    return newsItem(title: draft.title, body: draft.body);
  }
}
