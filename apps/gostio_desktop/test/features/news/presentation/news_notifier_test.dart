import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/news/data/news_query.dart';
import 'package:gostio_desktop/features/news/presentation/news_notifier.dart';

import '../../../support/news_double.dart';
import '../../../support/news_fixture.dart';

void main() {
  test('the newest articles are what the first page holds', () async {
    final NewsDouble news = NewsDouble(rows: <NewsItem>[newsItem()]);
    final NewsNotifier notifier = _notifier(news);

    await notifier.reload();

    expect(news.pages, <int>[1]);
    expect(
      notifier.items.single.title,
      'Kravice falls reopen after the high water',
    );
  });

  test('a term is applied from the first page', () async {
    final NewsDouble news = NewsDouble(
      rows: <NewsItem>[newsItem()],
      totalCount: 60,
    );
    final NewsNotifier notifier = _notifier(news);

    await notifier.openPage(3);
    await notifier.apply(const NewsQuery(title: 'Kravice'));

    expect(notifier.page, 1);
    expect(news.pages, <int>[3, 1]);
    expect(news.queries.last.toParameters(), <String, dynamic>{
      'title': 'Kravice',
    });
  });

  test('a read that failed leaves the message and its trace', () async {
    final NewsNotifier notifier = _notifier(NewsDouble(failing: true));

    await notifier.reload();

    expect(notifier.failureMessage, 'The articles could not be read.');
    expect(notifier.failureTraceId, 'a17f20');
    expect(notifier.items, isEmpty);
  });
}

NewsNotifier _notifier(NewsDouble news) {
  final NewsNotifier notifier = NewsNotifier(news);
  addTearDown(notifier.dispose);

  return notifier;
}
