import 'package:json_annotation/json_annotation.dart';

part 'stay_calendar_day.g.dart';

// One night of a stay as a guest reads it: whether it can still be booked and
// what it costs. The API answers the date alone, which parses to local
// midnight and so compares with the calendar days a picker holds.
//
// A night nobody may book is still answered, because a grid that omitted it
// would draw the month with a hole in it rather than with a night that is gone.
@JsonSerializable(createToJson: false)
class StayCalendarDay {
  const StayCalendarDay({
    required this.date,
    required this.isBookable,
    required this.price,
  });

  factory StayCalendarDay.fromJson(Map<String, dynamic> json) =>
      _$StayCalendarDayFromJson(json);

  final DateTime date;
  final bool isBookable;
  final double price;
}
