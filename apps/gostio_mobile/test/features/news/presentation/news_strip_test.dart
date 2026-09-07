import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/news/data/news_repository.dart';
import 'package:gostio_mobile/features/news/presentation/article_screen.dart';
import 'package:gostio_mobile/features/news/presentation/news_card.dart';
import 'package:gostio_mobile/features/news/presentation/news_notifier.dart';
import 'package:gostio_mobile/features/news/presentation/news_screen.dart';
import 'package:gostio_mobile/features/news/presentation/news_strip.dart';
import 'package:provider/provider.dart';

import '../../../support/auth_double.dart';
import '../../../support/news_double.dart';
import '../../../support/news_fixture.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> open(WidgetTester tester, NewsDouble news) async {
    await tester.pumpWidget(
      underTest(
        ChangeNotifierProvider<NewsNotifier>(
          create: (BuildContext context) =>
              NewsNotifier(context.read<NewsRepository>()),
          child: const Scaffold(body: NewsStrip()),
        ),
        auth: AuthDouble(),
        news: news,
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the front of the news is drawn over the results', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NewsDouble(
        rows: <NewsItem>[
          article(id: 1, title: 'A clearer cancellation policy'),
          article(id: 2, title: 'Host verification is faster'),
        ],
      ),
    );

    expect(find.text('News'), findsOneWidget);
    expect(find.text('A clearer cancellation policy'), findsOneWidget);
    expect(find.text('Host verification is faster'), findsOneWidget);
  });

  testWidgets('a card in the strip opens the article it is about', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NewsDouble(
        rows: <NewsItem>[article(title: 'Host verification is faster')],
      ),
    );

    await tester.tap(find.text('Host verification is faster'));
    await tester.pumpAndSettle();

    expect(find.byType(ArticleScreen), findsOneWidget);
  });

  testWidgets('the whole of it is one tap away', (WidgetTester tester) async {
    await open(tester, NewsDouble(rows: articles(3)));

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.byType(NewsScreen), findsOneWidget);
  });

  // Nothing published is not a fault and not news either, so the strip takes
  // no room on somebody else's screen rather than saying so in a space of its
  // own.
  testWidgets('nothing published draws no strip at all', (
    WidgetTester tester,
  ) async {
    await open(tester, NewsDouble());

    expect(find.text('News'), findsNothing);
  });

  // A refusal here is said in one line rather than in the screen state a whole
  // list gets: the results under it arrived.
  testWidgets('a refused read is said in a line with another go', (
    WidgetTester tester,
  ) async {
    final NewsDouble news = NewsDouble(
      failure: const ApiException(message: 'The API could not be reached.'),
    );
    await open(tester, news);

    expect(find.text('The API could not be reached.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(news.pagesAsked, <int>[1, 1]);
  });

  // Reaching the end of a strip is not a gesture that should fetch anything.
  // The list behind *See all* is where the rest of it is.
  testWidgets('the strip reads one page and no more', (
    WidgetTester tester,
  ) async {
    final NewsDouble news = NewsDouble(rows: articles(25));
    await open(tester, news);

    await tester.drag(find.byType(NewsCard).first, const Offset(-2000, 0));
    await tester.pumpAndSettle();

    expect(news.pagesAsked, <int>[1]);
  });
}
