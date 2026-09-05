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
    this.onChosen,
    this.figureFor,
    this.from,
    this.to,
    super.key,
  });

  final DateTime month;
  final DateTime? from;
  final DateTime? to;
  final bool Function(DateTime day) isTakeable;
  final bool Function(DateTime day) isSold;

  // A month with nothing to answer is read rather than chosen from: the
  // calendar on a listing says what is left, and the picker over it is where
  // a stay is actually taken.
  final ValueChanged<DateTime>? onChosen;

  // What is written under the day. A month that prices its nights is taller
  // for every cell rather than only for the ones that carry a figure, so the
  // weeks stay square.
  final String? Function(DateTime day)? figureFor;

  static const int _weeksDrawn = 6;

  double get _cellHeight => figureFor == null
      ? AppSizes.calendarCell
      : AppSizes.calendarCellWithFigure;

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
      return SizedBox(height: _cellHeight);
    }

    final DateTime? from = this.from;
    final DateTime? to = this.to;

    return _DayCell(
      day: day,
      height: _cellHeight,
      isFirst: day == from,
      isLast: day == to,
      isBetween:
          from != null && to != null && day.isAfter(from) && day.isBefore(to),
      isTakeable: isTakeable(day),
      isSold: isSold(day),
      figure: figureFor?.call(day),
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
    required this.height,
    required this.isFirst,
    required this.isLast,
    required this.isBetween,
    required this.isTakeable,
    required this.isSold,
    this.figure,
    this.onChosen,
  });

  final DateTime day;
  final double height;
  final bool isFirst;
  final bool isLast;
  final bool isBetween;
  final bool isTakeable;
  final bool isSold;
  final String? figure;
  final ValueChanged<DateTime>? onChosen;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool isEnd = isFirst || isLast;
    final ValueChanged<DateTime>? onChosen = this.onChosen;
    final VoidCallback? gesture = isTakeable && onChosen != null
        ? () => onChosen(day)
        : null;
    final Color ink = switch (<bool>[isEnd, isTakeable]) {
      [true, _] => AppColors.surface,
      [_, false] => AppColors.inkFaint,
      _ => AppColors.ink,
    };

    return Semantics(
      container: true,
      button: gesture != null,
      selected: isEnd || isBetween,
      enabled: isTakeable,
      label: _spoken,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Material(
          color: isBetween ? AppColors.selected : Colors.transparent,
          child: Ink(
            decoration: isEnd
                ? BoxDecoration(
                    color: AppColors.indigo,
                    // A circle over a cell that is taller than it is wide
                    // would be drawn as an ellipse, so a priced month keeps
                    // the corner radius the rest of the client is drawn in.
                    shape: figure == null
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: figure == null ? null : AppRadii.medium,
                  )
                : null,
            child: InkResponse(
              onTap: gesture,
              radius: height / 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${day.day}',
                    style: text.bodyMedium?.copyWith(
                      color: ink,
                      fontWeight: isEnd ? FontWeight.w600 : null,
                      // A night already sold is struck through rather than
                      // merely dimmed, which reads as a day that is simply
                      // late. It stays struck where it can still be tapped as
                      // the day of leaving, because the night is gone either
                      // way.
                      decoration: isSold ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (figure case final String figure)
                    Text(
                      figure,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: text.labelSmall?.copyWith(
                        color: isEnd ? AppColors.surface : AppColors.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _spoken {
    final StringBuffer spoken = StringBuffer(AppDates.day(day));

    if (isSold) {
      spoken.write(', taken');
    }

    if (figure case final String figure) {
      spoken.write(', $figure');
    }

    return spoken.toString();
  }
}
