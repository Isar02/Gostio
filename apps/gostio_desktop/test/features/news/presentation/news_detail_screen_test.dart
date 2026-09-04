import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:gostio_desktop/features/news/data/news_draft.dart';
import 'package:gostio_desktop/features/news/data/news_repository.dart';
import 'package:gostio_desktop/features/news/presentation/news_detail_notifier.dart';
import 'package:gostio_desktop/features/news/presentation/news_detail_screen.dart';
import 'package:gostio_desktop/features/news/presentation/news_form.dart';
import 'package:gostio_desktop/features/news/presentation/news_picture_field.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../support/news_double.dart';
import '../../../support/news_fixture.dart';

void main() {
  testWidgets('an article opens on what was written and who published it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(NewsDouble(), newsId: 3));
    await tester.pumpAndSettle();

    expect(
      find.text('Kravice falls reopen after the high water'),
      findsWidgets,
    );
    expect(find.textContaining('Amina Hodžić'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  // The API refuses an article written without a file, and it is refused here
  // first rather than sent for the server to refuse.
  testWidgets('an article written without a picture is never sent', (
    WidgetTester tester,
  ) async {
    final NewsDouble news = NewsDouble();
    await tester.pumpWidget(_screen(news));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Kravice reopen',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Text'),
      'The path down to the falls is walkable again.',
    );
    await tester.tap(find.text('Publish article'));
    await tester.pumpAndSettle();

    expect(news.written, isEmpty);
    expect(find.text('Choose an image to upload.'), findsOneWidget);
  });

  // A new article has nothing to delete and nothing to keep, so neither is
  // offered where one is being written.
  testWidgets('a new article is offered no delete and no stored picture', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(NewsDouble()));
    await tester.pumpAndSettle();

    expect(find.text('New article'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Choose a picture'), findsOneWidget);
    expect(
      tester.widget<NewsPictureField>(find.byType(NewsPictureField)).storedPath,
      isNull,
    );
  });

  // The article a write answered with is not the one the emptied form is for,
  // so nothing of it is offered to keep.
  testWidgets('the form that has published one is empty for the next', (
    WidgetTester tester,
  ) async {
    final NewsDouble news = NewsDouble();
    final NewsDetailNotifier notifier = NewsDetailNotifier(news, newsId: null);
    addTearDown(notifier.dispose);
    await notifier.load();
    await notifier.publishArticle(
      const NewsDraft(title: 'Kravice reopen', body: 'Walkable again.'),
      ImageUpload(name: 'kravice.png', bytes: pictureBytes),
    );

    await tester.pumpWidget(_form(notifier));
    await tester.pumpAndSettle();

    expect(find.text('Choose a picture'), findsOneWidget);
    expect(
      tester.widget<NewsPictureField>(find.byType(NewsPictureField)).storedPath,
      isNull,
    );
  });

  // A save with nothing behind it is not a write, and saying it was one would
  // be a success the server never gave.
  testWidgets('a save with nothing changed says so and stays', (
    WidgetTester tester,
  ) async {
    final NewsDouble news = NewsDouble();
    await tester.pumpWidget(_screen(news, newsId: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(news.written, isEmpty);
    expect(find.text('Nothing has changed.'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('an edited article is saved and handed back to the list', (
    WidgetTester tester,
  ) async {
    final NewsDouble news = NewsDouble();
    await tester.pumpWidget(_screen(news, newsId: 3));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Kravice falls reopen',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(news.written.single.title, 'Kravice falls reopen');
    expect(news.pictures.single, isNull);
  });

  testWidgets('what the API refused is said above the form it was typed in', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _screen(
        NewsDouble(
          refusing: const ApiException(
            message: 'One or more values are not valid.',
            statusCode: 400,
            errors: <String, List<String>>{
              'Body': <String>['Enter the text.'],
            },
          ),
        ),
        newsId: 3,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Kravice falls reopen',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('One or more values are not valid.'), findsOneWidget);
    expect(find.text('Enter the text.'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('a delete is confirmed before the article goes', (
    WidgetTester tester,
  ) async {
    final NewsDouble news = NewsDouble();
    await tester.pumpWidget(_screen(news, newsId: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this article?'), findsOneWidget);

    await tester.tap(find.text('Delete article'));
    await tester.pumpAndSettle();

    expect(news.deleted, <int>[3]);
  });

  testWidgets('an article that could not be read empties the screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_screen(NewsDouble(failing: true), newsId: 3));
    await tester.pumpAndSettle();

    expect(find.text('The article could not be read.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  group('the picture field', () {
    testWidgets('draws the file in hand rather than the one on the server', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _field(
          chosen: ImageUpload(name: 'kravice.png', bytes: pictureBytes),
          storedPath: '/news/3/image',
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsOneWidget);
      expect(find.textContaining('kravice.png'), findsOneWidget);
      expect(find.text('Keep the stored one'), findsOneWidget);
    });

    testWidgets('says what the bounds are while nothing is chosen', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_field());
      await tester.pump();

      expect(
        find.textContaining('JPEG, PNG or WebP, at most 4 MB.'),
        findsOneWidget,
      );
    });
  });
}

// The stored picture is fetched through the client like any other, and a
// request that goes nowhere leaves the frame empty, which is what a test of
// the form around it wants.
Widget _screen(NewsDouble news, {int? newsId}) => MultiProvider(
  providers: <SingleChildWidget>[
    Provider<ApiClient>(
      create: (BuildContext context) =>
          ApiClient(baseUrl: Uri.parse('http://localhost:5000')),
      dispose: (BuildContext context, ApiClient client) => client.close(),
    ),
    Provider<NewsRepository>.value(value: news),
  ],
  child: MaterialApp(
    home: Scaffold(body: NewsDetailScreen(newsId: newsId)),
  ),
);

Widget _form(NewsDetailNotifier notifier) => MaterialApp(
  home: Scaffold(
    body: NewsForm(
      notifier: notifier,
      onSaved: (NewsItem saved) {},
      onDeleted: (NewsItem deleted) {},
    ),
  ),
);

Widget _field({ImageUpload? chosen, String? storedPath}) => MaterialApp(
  home: Scaffold(
    body: NewsPictureField(
      chosen: chosen,
      storedPath: storedPath,
      isBusy: false,
      onChoose: () {},
      onKeepStored: chosen == null ? null : () {},
    ),
  ),
);
