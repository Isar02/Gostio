import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/section_header.dart';
import 'article_screen.dart';
import 'news_card.dart';
import 'news_notifier.dart';
import 'news_screen.dart';

// The front of the news, over the results on the landing. It scrolls away with
// them rather than standing over them: a strip pinned under the search would
// cost a third of a phone screen on every search a reader makes, and what they
// came for is under it.
//
// It reads the first page and no more. Reaching the end of a strip is not a
// gesture that should fetch anything; the list behind *See all* is where the
// rest of it is.
class NewsStrip extends StatelessWidget {
  const NewsStrip({super.key});

  static const double _cardWidth = 260;

  // A card at that width, drawn whole: its cover, the day it went out and up
  // to three lines of headline. A horizontal list has to be given a height,
  // and one short of the card it holds is a card that overflows.
  static const double _height = 284;

  @override
  Widget build(BuildContext context) {
    return Consumer<NewsNotifier>(
      builder: (BuildContext context, NewsNotifier news, Widget? child) {
        final Widget? body = _body(context, news);

        // Nothing published is not a fault and not news either, so the strip
        // is simply not drawn rather than saying so in a space of its own.
        if (body == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SectionHeader(
                'News',
                actionLabel: 'See all',
                onAction: () => unawaited(NewsScreen.open(context)),
              ),
              SizedBox(height: _height, child: body),
            ],
          ),
        );
      },
    );
  }

  // What the strip has to draw, or nothing where it has nothing to say.
  Widget? _body(BuildContext context, NewsNotifier news) {
    if (news.items.isEmpty) {
      if (news.isLoading) {
        return const LoadingState();
      }

      // A refusal here is said in one line rather than in the screen state a
      // whole list gets: the strip is a section of somebody else's screen and
      // the results under it arrived.
      if (news.failureMessage case final String refusal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppNotice(refusal),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: news.retry,
                child: const Text('Try again'),
              ),
            ),
          ],
        );
      }

      return null;
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: news.items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(width: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        final NewsItem item = news.items[index];

        return NewsCard(
          item,
          width: _cardWidth,
          onTap: () => unawaited(ArticleScreen.open(context, item)),
        );
      },
    );
  }
}
