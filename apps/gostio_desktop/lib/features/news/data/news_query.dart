import 'package:flutter/foundation.dart';
import 'package:gostio_core/gostio_core.dart';

// A filter nobody set is left out of the request rather than sent empty,
// which the API would read as a value to match.
@immutable
class NewsQuery {
  const NewsQuery({this.title, this.publishedFrom, this.publishedTo});

  final String? title;

  // Days off a calendar; what they narrow is a moment held in UTC.
  final DateTime? publishedFrom;
  final DateTime? publishedTo;

  bool get isEmpty => toParameters().isEmpty;

  JsonMap toParameters() => <String, dynamic>{
    'title': ?_written(title),
    'publishedFrom': ?_moment(publishedFrom),
    'publishedTo': ?_endOfDay(publishedTo),
  };

  @override
  bool operator ==(Object other) =>
      other is NewsQuery &&
      other.title == title &&
      other.publishedFrom == publishedFrom &&
      other.publishedTo == publishedTo;

  @override
  int get hashCode => Object.hash(title, publishedFrom, publishedTo);

  static String? _moment(DateTime? moment) =>
      moment == null ? null : Instants.write(moment);

  static String? _endOfDay(DateTime? day) =>
      day == null ? null : Instants.endOfDay(day);

  static String? _written(String? value) {
    final String? trimmed = value?.trim();

    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
