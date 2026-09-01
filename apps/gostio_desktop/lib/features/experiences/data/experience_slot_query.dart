import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/time/calendar_days.dart';

// The API matches the moment a term starts, so the second edge is the last
// instant of the day picked rather than that day's midnight.
@immutable
class ExperienceSlotQuery {
  const ExperienceSlotQuery({this.from, this.to, this.isActive});

  final DateTime? from;
  final DateTime? to;
  final bool? isActive;

  bool get isEmpty => toParameters().isEmpty;

  JsonMap toParameters() => <String, dynamic>{
    'from': ?_moment(from),
    'to': ?_moment(_endOfDay(to)),
    'isActive': ?isActive,
  };

  @override
  bool operator ==(Object other) =>
      other is ExperienceSlotQuery &&
      other.from == from &&
      other.to == to &&
      other.isActive == isActive;

  @override
  int get hashCode => Object.hash(from, to, isActive);

  static DateTime? _endOfDay(DateTime? day) => day == null
      ? null
      : CalendarDays.addDays(day, 1).subtract(const Duration(microseconds: 1));

  static String? _moment(DateTime? value) => value?.toUtc().toIso8601String();
}
