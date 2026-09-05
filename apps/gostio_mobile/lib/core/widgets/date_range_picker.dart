import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../calendar/date_range.dart';
import '../calendar/range_choice.dart';
import '../theme/app_metrics.dart';
import 'app_sheet.dart';
import 'bottom_action_bar.dart';
import 'discard_guard.dart';
import 'month_grid.dart';

// The dates for a stay, chosen over a month at a time. A night the listing
// has already sold is refused here rather than by the server after the
// reader has committed to it.
abstract final class DateRangePicker {
  static Future<DateRange?> show(
    BuildContext context, {
    DateRange? selected,
    DateTime? firstDay,
    DateTime? lastDay,
    Set<DateTime> unavailable = const <DateTime>{},
    String title = 'Choose your dates',
  }) => AppSheet.show<DateRange>(
    context,
    title: title,
    isScrollable: false,
    builder: (BuildContext context) => _RangeCalendar(
      selected: selected,
      firstDay: CalendarDays.of(firstDay ?? CalendarDays.today()),
      lastDay: lastDay == null ? null : CalendarDays.of(lastDay),
      unavailable: unavailable.map(CalendarDays.of).toSet(),
    ),
  );
}

class _RangeCalendar extends StatefulWidget {
  const _RangeCalendar({
    required this.firstDay,
    required this.unavailable,
    this.selected,
    this.lastDay,
  });

  final DateRange? selected;
  final DateTime firstDay;
  final DateTime? lastDay;
  final Set<DateTime> unavailable;

  @override
  State<_RangeCalendar> createState() => _RangeCalendarState();
}

class _RangeCalendarState extends State<_RangeCalendar> {
  late DateTime _month = CalendarDays.firstOfMonth(widget.firstDay);
  late RangeChoice _initial;
  late RangeChoice _choice;

  @override
  void initState() {
    super.initState();

    final RangeChoice empty = RangeChoice(
      firstDay: widget.firstDay,
      lastDay: widget.lastDay,
    );

    // Availability moves while the reader is elsewhere. A range chosen before
    // one of its nights was sold is no longer one this listing can take, so it
    // is dropped rather than handed back ready to be applied.
    final DateRange? selected = widget.selected;
    final bool isStillOffered =
        selected != null && empty.holds(selected, isNight: _isNight);

    _initial = _choice = isStillOffered
        ? RangeChoice(
            firstDay: widget.firstDay,
            lastDay: widget.lastDay,
            from: selected.from,
            to: selected.to,
          )
        : empty;

    if (isStillOffered) {
      _month = CalendarDays.firstOfMonth(selected.from);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DiscardGuard(
      hasInput: _choice != _initial,
      title: 'Leave these dates?',
      message: 'The dates you chose here will not be applied.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MonthBar(
            month: _month,
            onPrevious: _canGoBack ? () => _moveMonths(-1) : null,
            onNext: _canGoForward ? () => _moveMonths(1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: MonthGrid(
              month: _month,
              from: _choice.from,
              to: _choice.to,
              isTakeable: (DateTime day) =>
                  _choice.mayTake(day, isNight: _isNight),
              isSold: widget.unavailable.contains,
              onChosen: _choose,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          BottomActionBar(
            label: _choice.from == null ? 'Choose a first night' : _chosenLabel,
            detail: _choice.from == null ? null : _chosenDetail,
            secondary: TextButton(
              onPressed: _choice.from == null ? null : _clear,
              child: const Text('Clear'),
            ),
            action: FilledButton(
              onPressed: _choice.range == null
                  ? null
                  : () => Navigator.of(context).pop(_choice.range),
              child: const Text('Apply'),
            ),
          ),
        ],
      ),
    );
  }

  String get _chosenLabel {
    final DateRange? range = _choice.range;

    return range == null
        ? 'Choose a last night'
        : AppNumbers.counted(range.nights, 'night');
  }

  String get _chosenDetail {
    final DateTime from = _choice.from!;
    final DateTime? to = _choice.to;

    return to == null
        ? AppDates.day(from)
        : '${AppDates.day(from)} to ${AppDates.day(to)}';
  }

  bool get _canGoBack =>
      _month.isAfter(CalendarDays.firstOfMonth(widget.firstDay));

  bool get _canGoForward {
    final DateTime? lastDay = widget.lastDay;

    return lastDay == null ||
        _month.isBefore(CalendarDays.firstOfMonth(lastDay));
  }

  // Every day the sheet was handed as still on offer is a night that may be
  // bought; the window it has to fall inside is the choice's own.
  bool _isNight(DateTime day) => !widget.unavailable.contains(day);

  void _moveMonths(int months) =>
      setState(() => _month = CalendarDays.addMonths(_month, months));

  void _clear() => setState(() => _choice = _choice.cleared);

  void _choose(DateTime day) =>
      setState(() => _choice = _choice.take(day, isNight: _isNight));
}
