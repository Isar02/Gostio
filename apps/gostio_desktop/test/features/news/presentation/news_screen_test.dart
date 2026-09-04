import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/core/widgets/filter_bar.dart';
import 'package:gostio_desktop/features/news/data/news_repository.dart';
import 'package:gostio_desktop/features/news/presentation/news_screen.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/news_double.dart';
import '../../../support/news_fixture.dart';

void main() {
  testWidgets('an article is drawn by its title, its text and its author', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(NewsDouble(rows: <NewsItem>[newsItem()])));
    await tester.pumpAndSettle();

    expect(
      find.text('Kravice falls reopen after the high water'),
      findsOneWidget,
    );
    expect(find.text('Amina Hodžić'), findsOneWidget);
    expect(find.text('New article'), findsOneWidget);
  });

  // An article that has not been corrected has nothing in that cell, which
  // reads as a dash rather than as a column that failed to draw.
  testWidgets('an article nobody corrected reads as a dash', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(NewsDouble(rows: <NewsItem>[newsItem()])));
    await tester.pumpAndSettle();

    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('nothing published yet names what this list is for', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(NewsDouble()));
    await tester.pumpAndSettle();

    expect(find.text('No articles'), findsOneWidget);
  });

  testWidgets('a read that failed says what the API said, with its trace', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(NewsDouble(failing: true)));
    await tester.pumpAndSettle();

    expect(find.text('The articles could not be read.'), findsOneWidget);
    expect(find.text('Trace a17f20'), findsOneWidget);
  });

  testWidgets('a term settles before it is sent', (WidgetTester tester) async {
    final NewsDouble news = NewsDouble(rows: <NewsItem>[newsItem()]);
    await tester.pumpWidget(_screen(news));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Kravice');
    await tester.pump(FilterTextField.settle);
    await tester.pumpAndSettle();

    expect(news.queries.last.toParameters(), <String, dynamic>{
      'title': 'Kravice',
    });
  });

  // The detail is pushed over the list, and what it hands back is what makes
  // the list read itself again.
  testWidgets('a row opens the article it stands for and comes back saved', (
    WidgetTester tester,
  ) async {
    final NewsDouble news = NewsDouble(rows: <NewsItem>[newsItem()]);
    await tester.pumpWidget(_screen(news));
    await tester.pumpAndSettle();

    final Finder row = find.text('Kravice falls reopen after the high water');

    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(find.text('Save changes'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Kravice falls reopen',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Kravice falls reopen was saved.'), findsOneWidget);
    expect(news.pages, hasLength(2));
  });

  testWidgets('the new button opens the form with nothing in it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(NewsDouble()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New article'));
    await tester.pumpAndSettle();

    expect(find.text('Publish article'), findsOneWidget);
  });
}

// A row names its picture and the widget fetches it, so the client is here
// even though no test is about what comes back.
Widget _screen(NewsDouble news) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<ApiClient>(
      create: (BuildContext context) =>
          ApiClient(baseUrl: Uri.parse('http://localhost:5000')),
      dispose: (BuildContext context, ApiClient client) => client.close(),
    ),
    Provider<NewsRepository>.value(value: news),
  ],
  // The list sits in a navigator of its own, as it does in the shell, so the
  // detail it pushes stands over it rather than over the whole window.
  child: MaterialApp(
    home: Scaffold(
      body: Navigator(
        onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (BuildContext context) => const NewsScreen(),
        ),
      ),
    ),
  ),
);
