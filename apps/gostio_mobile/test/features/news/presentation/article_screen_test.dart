import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_mobile/features/news/presentation/article_screen.dart';

import '../../../support/auth_double.dart';
import '../../../support/news_fixture.dart';
import '../../../support/phone.dart';
import '../../../support/screens.dart';

void main() {
  setUp(usePhoneScreen);

  testWidgets('the article is drawn from the row the list handed it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      underTest(
        ArticleScreen(
          article(
            title: 'Experiences are now bookable alongside stays',
            body: 'A host can publish a guided experience with its own terms.',
            authorName: 'Amila Softić',
          ),
        ),
        auth: AuthDouble(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Experiences are now bookable alongside stays'),
      findsOneWidget,
    );
    expect(
      find.text('A host can publish a guided experience with its own terms.'),
      findsOneWidget,
    );
    expect(find.text('Amila Softić'), findsOneWidget);
  });

  // An article has to say when it went out, and the day alone leaves out half
  // of that. The moment is asked of the formatter rather than written out,
  // because what it prints moves with the machine's own zone.
  testWidgets('the article says the day it went out and the hour', (
    WidgetTester tester,
  ) async {
    final DateTime published = DateTime.utc(2026, 7, 27, 9);

    await tester.pumpWidget(
      underTest(
        ArticleScreen(article(publishedAt: published)),
        auth: AuthDouble(),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(AppDates.dateTime(published).toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(AppDates.date(published).toUpperCase()), findsNothing);
  });

  // A blank line between two runs of the body is the only structure the API
  // carries, so it is the only one drawn.
  testWidgets('a body written in two paragraphs is drawn as two', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      underTest(
        ArticleScreen(article(body: 'The first thing.\n\nThe second thing.')),
        auth: AuthDouble(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('The first thing.'), findsOneWidget);
    expect(find.text('The second thing.'), findsOneWidget);
  });

  testWidgets('an article that was changed says when', (
    WidgetTester tester,
  ) async {
    final DateTime edited = DateTime.utc(2026, 8, 3, 11);

    await tester.pumpWidget(
      underTest(ArticleScreen(article(modifiedAt: edited)), auth: AuthDouble()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edited ${AppDates.dateTime(edited)}'), findsOneWidget);
  });

  testWidgets('an article nobody changed says nothing about it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      underTest(ArticleScreen(article()), auth: AuthDouble()),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Edited'), findsNothing);
  });
}
