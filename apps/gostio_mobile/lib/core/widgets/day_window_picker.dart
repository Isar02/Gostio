import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../calendar/day_window.dart';
import '../theme/app_metrics.dart';
import 'app_sheet.dart';
import 'bottom_action_bar.dart';
import 'month_grid.dart';

// The days a term is looked for over. The first tap is already an answer — one
// day is a window — and a second later day widens it, because most of the time
// a reader looking for something to do is looking at one afternoon.
//
// Nothing is struck out here: which days a term actually runs on is the
// catalogue's answer rather than something a filter can know before it asks.
abstract final class DayWindowPicker {
  static Future<DayWindow?> show(
    BuildContext context, {
    DayWindow? selected,
    DateTime? firstDay,
    DateTime? lastDay,
    String title = 'Choose your days',
  }) => AppSheet.show<DayWindow>(
    context,
    title: title,
    isScrollable: false,
    isDraggable: true,
    builder: (BuildContext context) => _WindowCalendar(
      selected: selected,
      firstDay: CalendarDays.of(firstDay ?? CalendarDays.today()),
      lastDay: lastDay == null ? null : CalendarDays.of(lastDay),
    ),
  );
}

class _WindowCalendar extends StatefulWidget {
  const _WindowCalendar({required this.firstDay, this.selected, this.lastDay});

  final DayWindow? selected;
  final DateTime firstDay;
  final DateTime? lastDay;

  @override
  State<_WindowCalendar> createState() => _WindowCalendarState();
}

class _WindowCalendarState extends State<_WindowCalendar> {
  late DateTime _month = CalendarDays.firstOfMonth(widget.firstDay);
  DateTime? _from;
  DateTime? _to;
  bool _isWidened = false;

  @override
  void initState() {
    super.initState();

    // A window chosen yesterday may have fallen behind today while the reader
    // was elsewhere, and a day that can no longer be asked for is dropped
    // rather than handed back ready to be applied.
    final DayWindow? selected = widget.selected;
    if (selected != null && _isStillOffered(selected)) {
      _from = selected.from;
      _to = selected.to;
      _isWidened = !selected.isOneDay;
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
            isSold: (DateTime _) => false,
            onChosen: _choose,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        BottomActionBar(
          label: _window == null ? 'Choose a day' : _chosenLabel,
          detail: _chosenDetail,
          secondary: TextButton(
            onPressed: _from == null ? null : _clear,
            child: const Text('Clear'),
          ),
          action: FilledButton(
            onPressed: _window == null
                ? null
                : () => Navigator.of(context).pop(_window),
            child: const Text('Apply'),
          ),
        ),
      ],
    );
  }

  DayWindow? get _window {
    final DateTime? from = _from;
    final DateTime? to = _to;

    return from == null || to == null ? null : DayWindow(from: from, to: to);
  }

  String get _chosenLabel {
    final DayWindow window = _window!;

    return window.isOneDay ? 'One day' : '${window.days} days';
  }

  String? get _chosenDetail {
    final DayWindow? window = _window;

    return switch (window) {
      null => 'A term is looked for on the days you pick',
      _ when window.isOneDay => AppDates.day(window.from),
      _ => '${AppDates.day(window.from)} to ${AppDates.day(window.to)}',
    };
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
    _isWidened = false;
  });

  bool _isStillOffered(DayWindow window) {
    if (window.from.isBefore(widget.firstDay)) {
      return false;
    }

    final DateTime? lastDay = widget.lastDay;

    return lastDay == null || !window.to.isAfter(lastDay);
  }

  bool _isTakeable(DateTime day) {
    if (day.isBefore(widget.firstDay)) {
      return false;
    }

    final DateTime? lastDay = widget.lastDay;

    return lastDay == null || !day.isAfter(lastDay);
  }

  // One tap opens a window of a single day, which is a whole answer. The next
  // later day widens it, and any tap after that starts again — a window that
  // kept widening could never be narrowed without clearing it first.
  void _choose(DateTime day) {
    setState(() {
      final DateTime? from = _from;

      if (from == null || _isWidened || !day.isAfter(from)) {
        _from = day;
        _to = day;
        _isWidened = false;

        return;
      }

      _to = day;
      _isWidened = true;
    });
  }
}
