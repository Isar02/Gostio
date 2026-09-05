import 'dart:async';

import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/live_notifier.dart';
import '../data/listing_repository.dart';

// The month a listing's calendar is showing. One month is asked for at a time,
// which is well inside the window the API answers at once, and a month already
// read is kept: stepping back to it is not another request.
//
// Nothing here is chosen. This says what the listing has left and what each
// night costs; taking a range is the booking screen's gesture.
class StayCalendarNotifier extends LiveNotifier {
  StayCalendarNotifier(this._repository, this._accommodationId) {
    unawaited(show(firstMonth));
  }

  final ListingRepository _repository;
  final int _accommodationId;

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

  StayCalendarDay? dayOf(DateTime day) =>
      _months[_month]?[CalendarDays.of(day)];

  // A night before today is gone whatever the server says about it. The window
  // starts at the first of the month so that the grid is drawn whole, which
  // means the days already behind the reader come back with it.
  bool isBookable(DateTime day) =>
      !CalendarDays.of(day).isBefore(CalendarDays.today()) &&
      (dayOf(day)?.isBookable ?? false);

  // Somebody else holds this night, or the host has closed it. A night that
  // has merely gone by is not this: it is dimmed rather than struck, because
  // nothing was sold.
  bool isTaken(DateTime day) => dayOf(day)?.isBookable == false;

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
      days = await _repository.calendar(
        _accommodationId,
        from: month,
        to: CalendarDays.addDays(CalendarDays.addMonths(month, 1), -1),
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
