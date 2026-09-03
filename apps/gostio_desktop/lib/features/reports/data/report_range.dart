import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/time/calendar_days.dart';

// The days a report covers, closed at both ends. What the server would refuse
// is refused here first, so it is never asked for.
@immutable
class ReportRange {
  ReportRange({required DateTime from, required DateTime to})
    : from = CalendarDays.of(from),
      to = CalendarDays.of(to);

  factory ReportRange.rollingYearToToday() {
    final DateTime today = CalendarDays.today();

    return ReportRange(
      from: CalendarDays.addMonths(
        CalendarDays.firstOfMonth(today),
        -_monthsBefore,
      ),
      to: today,
    );
  }

  static const int maximumMonths = 24;

  final DateTime from;
  final DateTime to;

  // Months touched, so any part of a month counts as the whole of it.
  int get monthsCovered =>
      ((to.year - from.year) * 12) + to.month - from.month + 1;

  String? get refusal {
    if (to.isBefore(from)) {
      return 'A report cannot end before it starts.';
    }

    if (monthsCovered > maximumMonths) {
      return 'A report covers at most $maximumMonths months.';
    }

    return null;
  }

  bool get isAskable => refusal == null;

  JsonMap toParameters() => <String, dynamic>{
    'from': CalendarDays.write(from),
    'to': CalendarDays.write(to),
  };

  ReportRange startingOn(DateTime day) => ReportRange(from: day, to: to);

  ReportRange endingOn(DateTime day) => ReportRange(from: from, to: day);

  @override
  bool operator ==(Object other) =>
      other is ReportRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  static const int _monthsBefore = 11;
}
