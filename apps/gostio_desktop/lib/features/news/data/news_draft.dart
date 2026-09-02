import '../../../core/network/api_client.dart';
import 'news_item.dart';

// Both endpoints take a multipart body, so the text goes as fields.
class NewsDraft {
  const NewsDraft({required this.title, required this.body});

  final String title;
  final String body;

  JsonMap get fields => <String, dynamic>{'Title': title, 'Body': body};

  bool hasSameTextAs(NewsItem item) => item.title == title && item.body == body;
}
