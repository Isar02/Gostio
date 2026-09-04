import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/api_image.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/record_table.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/news_repository.dart';
import 'news_detail_screen.dart';
import 'news_filters.dart';
import 'news_notifier.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NewsNotifier>(
      create: (BuildContext context) {
        final NewsNotifier news = NewsNotifier(context.read<NewsRepository>());
        unawaited(news.reload());

        return news;
      },
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final NewsNotifier news = context.watch<NewsNotifier>();
    final String? failure = news.failureMessage;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          NewsFilters(
            applied: news.query,
            isLoading: news.isLoading,
            onChanged: news.apply,
            trailing: FilledButton.icon(
              onPressed: () => _open(context, news),
              icon: const Icon(Icons.add, size: AppSizes.iconSmall),
              label: const Text('New article'),
            ),
          ),
          if (failure != null && news.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(failure),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.stroke,
            child: news.isLoading ? const LinearProgressIndicator() : null,
          ),
          Expanded(
            child: RecordTable<NewsItem>(
              columns: _columns,
              rows: news.items,
              onRowOpen: (NewsItem row) => _open(context, news, id: row.id),
              empty: _Nothing(news: news),
              footer: PaginationFooter(
                page: news.page,
                pageSize: news.pageSize,
                totalCount: news.totalCount,
                onPageChanged: news.openPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // The detail is pushed over the list rather than beside it, and the list
  // reloads only when it hands back the article it wrote.
  Future<void> _open(BuildContext context, NewsNotifier news, {int? id}) async {
    final NewsItem? changed = await Navigator.of(context).push<NewsItem>(
      MaterialPageRoute<NewsItem>(
        builder: (BuildContext context) => NewsDetailScreen(newsId: id),
      ),
    );

    if (changed != null) {
      await news.reload();
    }
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.news});

  final NewsNotifier news;

  @override
  Widget build(BuildContext context) {
    if (news.isLoading) {
      return const LoadingState();
    }

    if (news.failureMessage case final String failure) {
      return ErrorState(
        message: failure,
        onRetry: news.reload,
        traceId: news.failureTraceId,
      );
    }

    return news.query.isEmpty
        ? const EmptyState(
            title: 'No articles',
            message:
                'Nothing has been published yet. What is written here is what '
                'guests read in the app.',
          )
        : const EmptyState(
            title: 'Nothing matches',
            message: 'No article answers every filter set above.',
          );
  }
}

// The title reads longest, and the text under it is read as its second line.
const int _titleShare = 3;
const int _bodyShare = 4;
const int _authorShare = 2;

final List<TableColumn<NewsItem>> _columns = <TableColumn<NewsItem>>[
  TableColumn<NewsItem>(
    label: '',
    width: AppSizes.thumbnailColumn,
    cell: (BuildContext context, NewsItem row) => ApiImage(
      path: row.imagePath,
      width: AppSizes.thumbnail,
      height: AppSizes.thumbnail,
    ),
  ),
  TableColumn<NewsItem>.text(
    label: 'Title',
    read: (NewsItem row) => row.title,
    flex: _titleShare,
  ),
  TableColumn<NewsItem>.text(
    label: 'Text',
    read: (NewsItem row) => row.body,
    flex: _bodyShare,
  ),
  TableColumn<NewsItem>.text(
    label: 'Author',
    read: (NewsItem row) => row.authorName,
    flex: _authorShare,
  ),
  TableColumn<NewsItem>.text(
    label: 'Published',
    read: (NewsItem row) => AppDates.date(row.publishedAt),
    width: AppSizes.dateColumn,
  ),
  TableColumn<NewsItem>.text(
    label: 'Edited',
    read: _editedOn,
    width: AppSizes.dateColumn,
  ),
];

String _editedOn(NewsItem row) => switch (row.modifiedAt) {
  final DateTime edited => AppDates.date(edited),
  null => '—',
};
