import '../../../core/models/paged_result.dart';
import '../../../core/paging/paged_notifier.dart';
import '../data/news_item.dart';
import '../data/news_query.dart';
import '../data/news_repository.dart';

class NewsNotifier extends PagedNotifier<NewsItem, NewsQuery> {
  NewsNotifier(this._news) : super(const NewsQuery());

  final NewsRepository _news;

  @override
  Future<PagedResult<NewsItem>> fetch({
    required int page,
    required NewsQuery query,
  }) => _news.search(query: query, page: page, pageSize: pageSize);
}
