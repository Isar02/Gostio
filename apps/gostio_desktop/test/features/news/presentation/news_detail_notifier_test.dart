import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/models/image_upload.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/news/data/news_draft.dart';
import 'package:gostio_desktop/features/news/presentation/news_detail_notifier.dart';

import '../../../support/news_double.dart';
import '../../../support/news_fixture.dart';

void main() {
  test('an article is published with the picture in hand', () async {
    final NewsDouble news = NewsDouble();
    final NewsDetailNotifier notifier = _notifier(news);
    await notifier.load();

    final NewsWrite outcome = await notifier.publishArticle(_draft, _picture);

    expect(outcome, NewsWrite.written);
    expect(notifier.item?.title, 'Kravice reopen');
    expect(news.written.single.fields, _draft.fields);
    expect(news.pictures.single?.name, 'kravice.png');
    expect(notifier.hasChanged, isTrue);
  });

  // The stored picture runs to megabytes, and an edit that left it alone has
  // no reason to send it back.
  test('an edit that left the picture alone sends none', () async {
    final NewsDouble news = NewsDouble();
    final NewsDetailNotifier notifier = _notifier(news, newsId: 3);
    await notifier.load();

    await notifier.saveChanges(_draft);

    expect(news.written, hasLength(1));
    expect(news.pictures.single, isNull);
  });

  // The endpoint stamps the article as edited for anything it is sent, so a
  // save with nothing behind it is not sent at all.
  test('a save with nothing changed writes nothing', () async {
    final NewsDouble news = NewsDouble();
    final NewsDetailNotifier notifier = _notifier(news, newsId: 3);
    await notifier.load();

    final NewsWrite outcome = await notifier.saveChanges(
      NewsDraft(title: newsItem().title, body: newsItem().body),
    );

    expect(outcome, NewsWrite.unchanged);
    expect(news.written, isEmpty);
    expect(notifier.hasChanged, isFalse);
  });

  test('a refused write is said above the form and changes nothing', () async {
    final NewsDouble news = NewsDouble(
      refusing: const ApiException(
        message: 'One or more values are not valid.',
        statusCode: 400,
        errors: <String, List<String>>{
          'Title': <String>['A title is at most 200 characters long.'],
        },
      ),
    );
    final NewsDetailNotifier notifier = _notifier(news);
    await notifier.load();

    final NewsWrite outcome = await notifier.publishArticle(_draft, _picture);

    expect(outcome, NewsWrite.refused);
    expect(notifier.writeFailureMessage, 'One or more values are not valid.');
    expect(
      notifier.messageFor('title'),
      'A title is at most 200 characters long.',
    );
    expect(notifier.hasChanged, isFalse);
    expect(notifier.isSaving, isFalse);
  });

  test('an article that could not be read leaves the screen empty', () async {
    final NewsDetailNotifier notifier = _notifier(
      NewsDouble(failing: true),
      newsId: 3,
    );

    await notifier.load();

    expect(notifier.item, isNull);
    expect(notifier.failureMessage, 'The article could not be read.');
  });

  test('a refused delete keeps the article and says why', () async {
    final NewsDouble news = NewsDouble(
      refusing: const ApiException(
        message: 'No news has the id 3.',
        statusCode: 404,
      ),
    );
    final NewsDetailNotifier notifier = _notifier(news, newsId: 3);
    await notifier.load();

    expect(await notifier.delete(), isFalse);
    expect(news.deleted, isEmpty);
    expect(notifier.writeFailureMessage, 'No news has the id 3.');
  });
}

const NewsDraft _draft = NewsDraft(
  title: 'Kravice reopen',
  body: 'The path down to the falls is walkable again.',
);

final ImageUpload _picture = ImageUpload(
  name: 'kravice.png',
  bytes: pictureBytes,
);

NewsDetailNotifier _notifier(NewsDouble news, {int? newsId}) {
  final NewsDetailNotifier notifier = NewsDetailNotifier(news, newsId: newsId);
  addTearDown(notifier.dispose);

  return notifier;
}
