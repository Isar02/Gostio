import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/news_item.dart';
import '../data/news_repository.dart';
import 'news_detail_notifier.dart';
import 'news_form.dart';

class NewsDetailScreen extends StatelessWidget {
  const NewsDetailScreen({this.newsId, super.key});

  // Absent means the screen is writing an article rather than editing one.
  final int? newsId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NewsDetailNotifier>(
      create: (BuildContext context) {
        final NewsDetailNotifier notifier = NewsDetailNotifier(
          context.read<NewsRepository>(),
          newsId: newsId,
        );
        unawaited(notifier.load());

        return notifier;
      },
      child: const _Detail(),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail();

  @override
  Widget build(BuildContext context) {
    final NewsDetailNotifier notifier = context.watch<NewsDetailNotifier>();

    if (notifier.isLoading) {
      return const LoadingState(message: 'Reading the article');
    }

    if (notifier.failureMessage case final String message) {
      return ErrorState(
        message: message,
        onRetry: notifier.load,
        traceId: notifier.failureTraceId,
      );
    }

    if (notifier.item == null && !notifier.isWriting) {
      return ErrorState(
        message: 'This article could not be read.',
        onRetry: notifier.load,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(notifier: notifier),
        Expanded(
          child: NewsForm(
            notifier: notifier,
            onSaved: (NewsItem saved) => _saved(context, notifier, saved),
            onDeleted: (NewsItem deleted) =>
                _leave(context, deleted, '${deleted.title} was deleted.'),
          ),
        ),
      ],
    );
  }

  // An edited article is on the page the list is showing; a published one is
  // not, so the form empties instead.
  static void _saved(
    BuildContext context,
    NewsDetailNotifier notifier,
    NewsItem saved,
  ) {
    if (!notifier.isWriting) {
      _leave(context, saved, '${saved.title} was saved.');

      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('${saved.title} was published.')));
  }

  static void _leave(BuildContext context, NewsItem article, String said) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(said)));
    Navigator.of(context).pop(article);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.notifier});

  final NewsDetailNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final NewsItem? article = notifier.isWriting ? null : notifier.item;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          // A save in flight would hand the list a row about to be wrong.
          IconButton(
            onPressed: notifier.isSaving
                ? null
                : () =>
                      Navigator.of(context)
                          .pop(notifier.hasChanged ? notifier.item : null),
            icon: const Icon(Icons.arrow_back),
            tooltip: notifier.isSaving
                ? 'The write in flight has to land first.'
                : 'Back to the list',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  article?.title ?? 'New article',
                  style: text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (article case final NewsItem article)
                  Text(
                    _said(article),
                    style: text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _said(NewsItem article) {
    final String published =
        '${article.authorName} · published '
        '${AppDates.date(article.publishedAt)}';

    return switch (article.modifiedAt) {
      final DateTime edited => '$published · edited ${AppDates.date(edited)}',
      null => published,
    };
  }
}
