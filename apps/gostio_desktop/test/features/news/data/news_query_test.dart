import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/time/instants.dart';
import 'package:gostio_desktop/features/news/data/news_query.dart';

void main() {
  test('a filter nobody set is left out of the request', () {
    expect(const NewsQuery().toParameters(), isEmpty);
    expect(const NewsQuery().isEmpty, isTrue);
    expect(const NewsQuery(title: '   ').toParameters(), isEmpty);
  });

  test('a term is sent trimmed', () {
    expect(
      const NewsQuery(title: '  Neretva ').toParameters(),
      <String, dynamic>{'title': 'Neretva'},
    );
  });

  // The API holds a moment in UTC and the reader picks a day off a calendar
  // where they stand, so the window is that day written as two instants.
  test('a window starts at the first moment of the day it names', () {
    final DateTime day = DateTime(2026, 9, 2);

    expect(NewsQuery(publishedFrom: day).toParameters(), <String, dynamic>{
      'publishedFrom': Instants.write(day),
    });
  });

  // An article published this afternoon is one published today, so the far
  // edge runs to the last tick of its day rather than to its first moment.
  test('a window ends at the last tick of the day it names', () {
    final DateTime day = DateTime(2026, 9, 2);

    expect(NewsQuery(publishedTo: day).toParameters(), <String, dynamic>{
      'publishedTo': Instants.endOfDay(day),
    });
    expect(
      NewsQuery(publishedTo: day).toParameters()['publishedTo'],
      endsWith('.9999999'),
    );
  });

  test('two queries holding the same filters are the same query', () {
    final DateTime day = DateTime(2026, 9, 2);

    expect(
      NewsQuery(title: 'Neretva', publishedFrom: day),
      NewsQuery(title: 'Neretva', publishedFrom: day),
    );
    expect(NewsQuery(publishedFrom: day), isNot(NewsQuery(publishedTo: day)));
  });
}
