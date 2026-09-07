import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/news/data/news_repository.dart';

// What the platform has published, answered without a server. It pages what it
// was given the way the API would.
class NewsDouble implements NewsRepository {
  NewsDouble({this.rows = const <NewsItem>[], this.failure});

  final List<NewsItem> rows;
  final ApiException? failure;

  final List<int> pagesAsked = <int>[];

  @override
  Future<PagedResult<NewsItem>> search({
    required int page,
    required int pageSize,
  }) async {
    pagesAsked.add(page);

    if (failure case final ApiException refused) {
      throw refused;
    }

    final int from = ((page - 1) * pageSize).clamp(0, rows.length);
    final int to = (from + pageSize).clamp(0, rows.length);

    return PagedResult<NewsItem>(
      items: rows.sublist(from, to),
      page: page,
      pageSize: pageSize,
      totalCount: rows.length,
    );
  }
}
