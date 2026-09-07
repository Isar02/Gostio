import 'package:gostio_core/gostio_core.dart';

// An article the way the API answers one.
NewsItem article({
  int id = 1,
  String title = 'Experiences are now bookable alongside stays',
  String body =
      'A host can publish a guided experience with its own terms, and a '
      'guest books a concrete term rather than the experience in the '
      'abstract.',
  String authorName = 'Amila Softić',
  DateTime? publishedAt,
  DateTime? modifiedAt,
}) => NewsItem(
  id: id,
  title: title,
  body: body,
  imageContentType: 'image/jpeg',
  authorId: 2,
  authorName: authorName,
  publishedAt: publishedAt ?? DateTime.utc(2026, 7, 27, 9),
  modifiedAt: modifiedAt,
);

List<NewsItem> articles(int count) => <NewsItem>[
  for (int index = 1; index <= count; index++)
    article(
      id: index,
      title: 'Article $index',
      publishedAt: DateTime.utc(2026, 7, index + 1, 9),
    ),
];
