import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// The month a grid is showing, and the way out of it. Which months may be
// reached is the caller's business: a null gesture is a month that is not
// offered.
class MonthBar extends StatelessWidget {
  const MonthBar({
    required this.month,
    this.onPrevious,
    this.onNext,
    super.key,
  });

  final DateTime month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous month',
          ),
          Expanded(
            child: Text(
              AppDates.month(month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next month',
          ),
        ],
      ),
    );
  }
}

// One month drawn as whole weeks. It knows which days may be tapped and which
// nights are already sold; what a chosen pair of days means is the caller's.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.month,
    required this.isTakeable,
    required this.isSold,
    required this.onChosen,
    this.from,
    this.to,
    super.key,
  });

  final DateTime month;
  final DateTime? from;
  final DateTime? to;
  final bool Function(DateTime day) isTakeable;
  final bool Function(DateTime day) isSold;
  final ValueChanged<DateTime> onChosen;

  static const int _weeksDrawn = 6;

  @override
  Widget build(BuildContext context) {
    // The grid starts on the Monday on or before the first of the month, so
    // every month is drawn as whole weeks and the columns never shift.
    final DateTime start = CalendarDays.startOfWeek(month);
    final DateTime nextMonth = CalendarDays.addMonths(month, 1);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const _WeekdayRow(),
        for (int week = 0; week < _weeksDrawn; week++)
          if (CalendarDays.addDays(
            start,
            week * DateTime.daysPerWeek,
          ).isBefore(nextMonth))
            Row(
              children: <Widget>[
                for (int day = 0; day < DateTime.daysPerWeek; day++)
                  Expanded(
                    child: _cell(
                      CalendarDays.addDays(
                        start,
                        week * DateTime.daysPerWeek + day,
                      ),
                      nextMonth,
                    ),
                  ),
              ],
            ),
      ],
    );
  }

  // The days a week borrows from the month on either side hold their column
  // and draw nothing, so the weeks stay square.
  Widget _cell(DateTime day, DateTime nextMonth) {
    if (day.isBefore(month) || !day.isBefore(nextMonth)) {
      return const SizedBox(height: AppSizes.calendarCell);
    }

    final DateTime? from = this.from;
    final DateTime? to = this.to;

    return _DayCell(
      day: day,
      isFirst: day == from,
      isLast: day == to,
      isBetween:
          from != null && to != null && day.isAfter(from) && day.isBefore(to),
      isTakeable: isTakeable(day),
      isSold: isSold(day),
      onChosen: onChosen,
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow();

  @override
  Widget build(BuildContext context) {
    final DateTime week = CalendarDays.startOfWeek(CalendarDays.today());

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          for (int day = 0; day < DateTime.daysPerWeek; day++)
            Expanded(
              child: Text(
                AppDates.weekday(CalendarDays.addDays(week, day)),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isFirst,
    required this.isLast,
    required this.isBetween,
    required this.isTakeable,
    required this.isSold,
    required this.onChosen,
  });

  final DateTime day;
  final bool isFirst;
  final bool isLast;
  final bool isBetween;
  final bool isTakeable;
  final bool isSold;
  final ValueChanged<DateTime> onChosen;

  @override
  Widget build(BuildContext context) {
    final bool isEnd = isFirst || isLast;

    return Semantics(
      container: true,
      button: isTakeable,
      selected: isEnd || isBetween,
      enabled: isTakeable,
      label: AppDates.day(day),
      excludeSemantics: true,
      child: SizedBox(
        height: AppSizes.calendarCell,
        child: Material(
          color: isBetween ? AppColors.selected : Colors.transparent,
          child: Ink(
            decoration: isEnd
                ? const BoxDecoration(
                    color: AppColors.indigo,
                    shape: BoxShape.circle,
                  )
                : null,
            child: InkResponse(
              onTap: isTakeable ? () => onChosen(day) : null,
              radius: AppSizes.calendarCell / 2,
              child: Center(
                child: Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: switch (<bool>[isEnd, isTakeable]) {
                      [true, _] => AppColors.surface,
                      [_, false] => AppColors.inkFaint,
                      _ => AppColors.ink,
                    },
                    fontWeight: isEnd ? FontWeight.w600 : null,
                    // A night already sold is struck through rather than
                    // merely dimmed, which reads as a day that is simply late.
                    // It stays struck where it can still be tapped as the day
                    // of leaving, because the night is gone either way.
                    decoration: isSold ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
