import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import '../state/live_notifier.dart';

// The window a calendar is read over, which the API bounds rather than pages.
typedef StayNightsReader = Future<List<StayCalendarDay>> Function(
  DateTime from,
  DateTime to,
);

// The month a stay's calendar is showing. One month is asked for at a time,
// which is well inside the window the API answers at once, and a month already
// read is kept: stepping back to it is not another request.
//
// What is drawn from it is the caller's. A listing reads it to say what is
// left and what each night costs; the booking screen reads the same months to
// take a range out of them and to price it from the figures the server will
// use. Which listing the nights belong to is the reader function's business,
// so nothing here knows a route.
class StayCalendarNotifier extends LiveNotifier {
  StayCalendarNotifier(this._readNights) {
    unawaited(show(firstMonth));
  }

  final StayNightsReader _readNights;

  final Map<DateTime, Map<DateTime, StayCalendarDay>> _months =
      <DateTime, Map<DateTime, StayCalendarDay>>{};

  int _request = 0;
  bool _isLoading = false;
  ApiException? _failure;
  late DateTime _month = firstMonth;

  // A month already gone has no night left to sell, so the calendar does not
  // step back past the one it is being read in.
  DateTime get firstMonth => CalendarDays.firstOfMonth(CalendarDays.today());

  DateTime get month => _month;

  bool get isLoading => _isLoading;

  bool get canGoBack => _month.isAfter(firstMonth);

  bool get hasLanded => _months.containsKey(_month);

  String? get failureMessage => _failure?.message;

  // Filed under the month the day belongs to rather than the month on screen,
  // so a stay that runs over a month end is priced from both of them.
  StayCalendarDay? nightOf(DateTime day) =>
      _months[CalendarDays.firstOfMonth(day)]?[CalendarDays.of(day)];

  // A night before today is gone whatever the server says about it. The window
  // starts at the first of the month so that the grid is drawn whole, which
  // means the days already behind the reader come back with it.
  //
  // A month that has not landed answers no, which is what keeps a range from
  // being taken across nights nobody has been told the price of.
  bool isBookable(DateTime day) =>
      !CalendarDays.of(day).isBefore(CalendarDays.today()) &&
      (nightOf(day)?.isBookable ?? false);

  // Somebody else holds this night, or the host has closed it. A night that
  // has merely gone by is not this: it is dimmed rather than struck, because
  // nothing was sold.
  bool isTaken(DateTime day) => nightOf(day)?.isBookable == false;

  Future<void> show(DateTime month) {
    _month = CalendarDays.firstOfMonth(month);
    _failure = null;

    if (_months.containsKey(_month)) {
      publish();

      return Future<void>.value();
    }

    return _read(_month);
  }

  Future<void> moveMonths(int months) =>
      show(CalendarDays.addMonths(_month, months));

  Future<void> retry() => show(_month);

  Future<void> _read(DateTime month) async {
    final int request = ++_request;

    _isLoading = true;
    publish();

    List<StayCalendarDay>? days;
    ApiException? failure;

    try {
      days = await _readNights(
        month,
        CalendarDays.addDays(CalendarDays.addMonths(month, 1), -1),
      );
    } on ApiException catch (refused) {
      failure = refused;
    }

    // A month that landed is kept whichever month is being read now, because
    // it is filed under its own key. What the screen is told, though, is only
    // ever the newest request's business.
    if (days case final List<StayCalendarDay> landed) {
      _months[month] = <DateTime, StayCalendarDay>{
        for (final StayCalendarDay day in landed)
          CalendarDays.of(day.date): day,
      };
    }

    if (request != _request) {
      return;
    }

    _failure = failure;
    _isLoading = false;
    publish();
  }
}
