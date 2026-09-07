import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/paged_list.dart';
import '../data/news_repository.dart';
import 'article_screen.dart';
import 'news_card.dart';
import 'news_notifier.dart';

// Everything that has been published, which the strip on the landing shows the
// front of. It is pushed into whichever tab it was opened from, so the bar
// under it stays and closing it comes back to where the reader was.
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => const NewsScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NewsNotifier>(
      create: (BuildContext context) =>
          NewsNotifier(context.read<NewsRepository>()),
      child: Scaffold(
        appBar: AppBar(title: const Text('News')),
        body: SafeArea(
          child: Consumer<NewsNotifier>(
            builder: (BuildContext context, NewsNotifier news, Widget? child) =>
                PagedList<NewsItem>(
                  items: news.items,
                  totalCount: news.totalCount,
                  noun: 'articles',
                  isLoading: news.isLoading,
                  isAppending: news.isAppending,
                  failureMessage: news.failureMessage,
                  failureTraceId: news.failureTraceId,
                  onMore: news.more,
                  onRetry: news.retry,
                  onRefresh: news.reload,
                  emptyTitle: 'Nothing published yet',
                  emptyMessage: 'What changes on Gostio is announced here.',
                  itemBuilder: (BuildContext context, NewsItem item) =>
                      NewsCard(
                        item,
                        onTap: () =>
                            unawaited(ArticleScreen.open(context, item)),
                      ),
                ),
          ),
        ),
      ),
    );
  }
}
