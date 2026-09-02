import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/features/news/data/news_draft.dart';

import '../../../support/news_fixture.dart';

void main() {
  // Both endpoints take a form rather than JSON, and they bind these two
  // fields by the names the API gives them.
  test('the text goes as the fields the form carries', () {
    const NewsDraft draft = NewsDraft(
      title: 'Kravice reopen',
      body: 'Walkable',
    );

    expect(draft.fields, <String, dynamic>{
      'Title': 'Kravice reopen',
      'Body': 'Walkable',
    });
  });

  test('a draft knows when it says what the article already says', () {
    expect(
      NewsDraft(
        title: newsItem().title,
        body: newsItem().body,
      ).hasSameTextAs(newsItem()),
      isTrue,
    );
    expect(
      NewsDraft(
        title: newsItem().title,
        body: 'The path is closed again.',
      ).hasSameTextAs(newsItem()),
      isFalse,
    );
  });
}
