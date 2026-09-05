import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../calendar/stay_calendar_notifier.dart';
import '../theme/app_metrics.dart';
import 'app_notice.dart';
import 'month_grid.dart';
import 'screen_states.dart';

// One month of a stay's calendar: the way out of it, the nights it has left
// and what each of them costs. Reading a month and choosing a range out of one
// are the same drawing, so both screens that show nights show this.
//
// Whether a day answers a tap is the caller's: a listing says what is left and
// a booking screen takes a range out of it.
class StayMonthCalendar extends StatelessWidget {
  const StayMonthCalendar({
    required this.calendar,
    this.from,
    this.to,
    this.isTakeable,
    this.onChosen,
    super.key,
  });

  final StayCalendarNotifier calendar;
  final DateTime? from;
  final DateTime? to;
  final bool Function(DateTime day)? isTakeable;
  final ValueChanged<DateTime>? onChosen;

  // Roughly the room a month takes, held while one is being read so that the
  // page under it does not lurch when it lands.
  //
  // The grid itself is not held to it. A month drawn as six whole weeks is
  // taller than this — the weekdays above it are a row of their own — and a box
  // that fixed the height would clip the last week of every such month.
  static const double _whileRead = AppSizes.calendarCellWithFigure * 6;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        MonthBar(
          month: calendar.month,
          onPrevious: calendar.canGoBack ? () => calendar.moveMonths(-1) : null,
          onNext: () => calendar.moveMonths(1),
        ),
        _month(),
      ],
    );
  }

  Widget _month() {
    if (!calendar.hasLanded) {
      if (calendar.isLoading) {
        return const SizedBox(height: _whileRead, child: LoadingState());
      }

      if (calendar.failureMessage case final String message) {
        return SizedBox(
          height: _whileRead,
          child: Column(
            children: <Widget>[
              AppNotice(message),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: calendar.retry,
                child: const Text('Try again'),
              ),
            ],
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: MonthGrid(
        month: calendar.month,
        from: from,
        to: to,
        isTakeable: isTakeable ?? calendar.isBookable,
        isSold: calendar.isTaken,
        onChosen: onChosen,
        figureFor: _price,
      ),
    );
  }

  // A night nobody may book any more is not priced: the figure under a day is
  // what it would cost to take it, and a night that is gone costs nothing.
  String? _price(DateTime day) {
    if (!calendar.isBookable(day)) {
      return null;
    }

    final StayCalendarDay? night = calendar.nightOf(day);

    return night == null ? null : AppNumbers.typed(night.price);
  }
}
