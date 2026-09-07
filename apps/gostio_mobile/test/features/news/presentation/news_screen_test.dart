import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/news/presentation/article_screen.dart';
import 'package:gostio_mobile/features/news/presentation/news_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/news_double.dart';
import '../../../support/news_fixture.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  Future<void> open(WidgetTester tester, NewsDouble news) async {
    await tester.pumpWidget(
      underTest(const NewsScreen(), auth: AuthDouble(), news: news),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300);
    await tester.pumpAndSettle();
  }

  testWidgets('an article is drawn with its title and the day it went out', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NewsDouble(
        rows: <NewsItem>[
          article(
            title: 'A clearer cancellation policy',
            publishedAt: DateTime.utc(2026, 8, 17, 9),
          ),
        ],
      ),
    );

    expect(find.text('A clearer cancellation policy'), findsOneWidget);
    expect(find.text('17 AUG 2026'), findsOneWidget);
  });

  testWidgets('an account with nothing published is told so', (
    WidgetTester tester,
  ) async {
    await open(tester, NewsDouble());

    expect(find.text('Nothing published yet'), findsOneWidget);
  });

  testWidgets('the footer says how much of the whole is held', (
    WidgetTester tester,
  ) async {
    await open(tester, NewsDouble(rows: articles(25)));
    await scrollTo(tester, find.text('20 of 25 articles'));

    expect(find.text('20 of 25 articles'), findsOneWidget);
  });

  testWidgets('a row opens the article it is about', (
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

  testWidgets('a refused read is said with the trace it can be found by', (
    WidgetTester tester,
  ) async {
    await open(
      tester,
      NewsDouble(
        failure: const ApiException(
          message: 'The API could not be reached.',
          traceId: '00-abc-def-01',
        ),
      ),
    );

    expect(find.text('The API could not be reached.'), findsOneWidget);
    expect(find.text('Trace 00-abc-def-01'), findsOneWidget);
  });
}
