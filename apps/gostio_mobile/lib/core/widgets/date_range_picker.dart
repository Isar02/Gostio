import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../calendar/date_range.dart';
import '../theme/app_metrics.dart';
import 'app_sheet.dart';
import 'bottom_action_bar.dart';
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
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();

    // Availability moves while the reader is elsewhere. A range chosen before
    // one of its nights was sold is no longer one this listing can take, so it
    // is dropped rather than handed back ready to be applied.
    final DateRange? selected = widget.selected;
    if (selected != null && _isStillOffered(selected)) {
      _from = selected.from;
      _to = selected.to;
      _month = CalendarDays.firstOfMonth(selected.from);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
            from: _from,
            to: _to,
            isTakeable: _isTakeable,
            isSold: widget.unavailable.contains,
            onChosen: _choose,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        BottomActionBar(
          label: _from == null ? 'Choose a first night' : _chosenLabel,
          detail: _from == null ? null : _chosenDetail,
          secondary: TextButton(
            onPressed: _from == null ? null : _clear,
            child: const Text('Clear'),
          ),
          action: FilledButton(
            onPressed: _range == null
                ? null
                : () => Navigator.of(context).pop(_range),
            child: const Text('Apply'),
          ),
        ),
      ],
    );
  }

  DateRange? get _range {
    final DateTime? from = _from;
    final DateTime? to = _to;

    return from == null || to == null ? null : DateRange(from: from, to: to);
  }

  String get _chosenLabel {
    final DateRange? range = _range;

    return range == null
        ? 'Choose a last night'
        : '${range.nights} ${range.nights == 1 ? "night" : "nights"}';
  }

  String get _chosenDetail {
    final DateTime from = _from!;
    final DateTime? to = _to;

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

  void _moveMonths(int months) =>
      setState(() => _month = CalendarDays.addMonths(_month, months));

  void _clear() => setState(() {
    _from = null;
    _to = null;
  });

  bool _isStillOffered(DateRange range) {
    if (range.from.isBefore(widget.firstDay)) {
      return false;
    }

    final DateTime? lastDay = widget.lastDay;
    if (lastDay != null && range.to.isAfter(lastDay)) {
      return false;
    }

    return !widget.unavailable.any(range.holdsNight);
  }

  bool _isTakeable(DateTime day) {
    if (day.isBefore(widget.firstDay)) {
      return false;
    }

    final DateTime? lastDay = widget.lastDay;
    if (lastDay != null && day.isAfter(lastDay)) {
      return false;
    }

    // While a first night is held and a last one is not, the day the reader
    // leaves may be a night somebody else has bought: they are gone by then.
    final DateTime? from = _from;
    if (from != null &&
        _to == null &&
        day.isAfter(from) &&
        !_holdsSoldNight(from, day)) {
      return true;
    }

    return !widget.unavailable.contains(day);
  }

  // The first tap opens a range and the second closes it. A second tap that
  // cannot close one — before the first night, or across a night somebody
  // else already holds — opens a new range instead of refusing the gesture.
  void _choose(DateTime day) {
    setState(() {
      final DateTime? from = _from;

      if (from == null ||
          _to != null ||
          !day.isAfter(from) ||
          _holdsSoldNight(from, day)) {
        _from = day;
        _to = null;

        return;
      }

      _to = day;
    });
  }

  // A stay occupies the nights up to the day it ends on, so the day the
  // reader leaves may be sold to somebody else and the ones before it may not.
  bool _holdsSoldNight(DateTime from, DateTime to) =>
      widget.unavailable.any(DateRange(from: from, to: to).holdsNight);
}
