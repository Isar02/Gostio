import 'package:json_annotation/json_annotation.dart';

part 'news_item.g.dart';

// No list carries bytes, so a row names where its picture is read from.
@JsonSerializable(createToJson: false)
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.imageContentType,
    required this.authorId,
    required this.authorName,
    required this.publishedAt,
    this.modifiedAt,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) =>
      _$NewsItemFromJson(json);

  final int id;
  final String title;
  final String body;
  final String imageContentType;
  final int authorId;
  final String authorName;
  final DateTime publishedAt;
  final DateTime? modifiedAt;

  String get imagePath => '/news/$id/image';
}
