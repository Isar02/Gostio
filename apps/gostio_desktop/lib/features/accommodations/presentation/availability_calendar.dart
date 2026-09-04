import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../listings/presentation/booking_colours.dart';
import 'availability_month.dart';
import 'availability_words.dart';

class AvailabilityCalendar extends StatelessWidget {
  const AvailabilityCalendar({
    required this.shown,
    required this.highlight,
    required this.isHighlightRefused,
    required this.onChoose,
    required this.onReach,
    super.key,
  });

  final AvailabilityMonth shown;

  final (DateTime, DateTime)? highlight;
  final bool isHighlightRefused;

  final ValueChanged<AvailabilityDay> onChoose;
  final ValueChanged<AvailabilityDay> onReach;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: AppRadii.large,
        child: Column(
          children: <Widget>[
            _Weekdays(days: shown.weeks.first.days),
            for (final AvailabilityWeek week in shown.weeks)
              Expanded(
                child: _Week(
                  week: week,
                  isRinged: _isRinged,
                  isHighlightRefused: isHighlightRefused,
                  onChoose: onChoose,
                  onReach: onReach,
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _isRinged(DateTime date) {
    if (highlight case (final DateTime from, final DateTime to)) {
      return !date.isBefore(from) && !date.isAfter(to);
    }

    return false;
  }
}

class _Weekdays extends StatelessWidget {
  const _Weekdays({required this.days});

  final List<AvailabilityDay> days;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.hover,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          for (final AvailabilityDay day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Text(
                  AppDates.weekday(day.date),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({
    required this.week,
    required this.isRinged,
    required this.isHighlightRefused,
    required this.onChoose,
    required this.onReach,
  });

  final AvailabilityWeek week;
  final bool Function(DateTime date) isRinged;
  final bool isHighlightRefused;
  final ValueChanged<AvailabilityDay> onChoose;
  final ValueChanged<AvailabilityDay> onReach;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (final AvailabilityDay day in week.days)
              Expanded(
                child: _Day(
                  day: day,
                  isRinged: isRinged(day.date),
                  isHighlightRefused: isHighlightRefused,
                  onChoose: () => onChoose(day),
                  onReach: () => onReach(day),
                ),
              ),
          ],
        ),
        // The bars sit over the cells, and the day under one has to stay
        // reachable rather than stop at the guest's name.
        Positioned(
          left: 0,
          right: 0,
          bottom: AppSpacing.sm,
          height: AppSizes.calendarBar,
          child: IgnorePointer(child: _Bars(bars: week.bars)),
        ),
      ],
    );
  }
}

// The bars share the seven columns with the cells under them, so a stay is
// laid out in the same flex the days are rather than measured in pixels.
class _Bars extends StatelessWidget {
  const _Bars({required this.bars});

  final List<BookingBar> bars;

  @override
  Widget build(BuildContext context) {
    final List<Widget> columns = <Widget>[];
    int filled = 0;

    for (final BookingBar bar in bars) {
      if (bar.column > filled) {
        columns.add(Spacer(flex: bar.column - filled));
      }

      columns.add(
        Expanded(
          flex: bar.span,
          child: _Bar(bar: bar),
        ),
      );
      filled = bar.column + bar.span;
    }

    if (filled < DateTime.daysPerWeek) {
      columns.add(Spacer(flex: DateTime.daysPerWeek - filled));
    }

    return Row(children: columns);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.bar});

  final BookingBar bar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        left: bar.startsHere ? AppSpacing.xs : 0,
        right: bar.endsHere ? AppSpacing.xs : 0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: _ground,
        borderRadius: BorderRadius.horizontal(
          left: bar.startsHere ? AppRadii.smallRadius : Radius.zero,
          right: bar.endsHere ? AppRadii.smallRadius : Radius.zero,
        ),
      ),
      child: Text(
        _label,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: AppColors.surface),
      ),
    );
  }

  Color get _ground => BookingColours.bar(bar.booking.standing);

  String get _label => bar.startsHere
      ? '${bar.booking.guestName} · ${bar.booking.guestCount}'
      : bar.booking.guestName;
}

class _Day extends StatefulWidget {
  const _Day({
    required this.day,
    required this.isRinged,
    required this.isHighlightRefused,
    required this.onChoose,
    required this.onReach,
  });

  final AvailabilityDay day;
  final bool isRinged;
  final bool isHighlightRefused;
  final VoidCallback onChoose;
  final VoidCallback onReach;

  @override
  State<_Day> createState() => _DayState();
}

class _DayState extends State<_Day> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final AvailabilityDay day = widget.day;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (PointerEnterEvent event) {
        setState(() => _isHovered = true);
        widget.onReach();
      },
      onExit: (PointerExitEvent event) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onChoose,
        child: _Told(
          day: day,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                right: const BorderSide(
                  color: AppColors.border,
                  width: AppSizes.hairline,
                ),
                bottom: const BorderSide(
                  color: AppColors.border,
                  width: AppSizes.hairline,
                ),
                top: BorderSide(color: _ring, width: AppSizes.focusRing),
                left: BorderSide(color: _ring, width: AppSizes.focusRing),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ColoredBox(color: _ground),
                if (day.isBlocked) const CustomPaint(painter: _Hatching()),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _Number(day: day),
                      const Spacer(),
                      if (day.priceOverride case final double price
                          when day.isRepriced)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            AppNumbers.money(price),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.indigo),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color get _ring {
    if (!widget.isRinged) {
      return Colors.transparent;
    }

    return widget.isHighlightRefused ? AppColors.danger : AppColors.indigo;
  }

  Color get _ground {
    if (widget.isRinged) {
      return widget.isHighlightRefused
          ? AppColors.dangerGround
          : AppColors.selected;
    }

    if (!widget.day.isInMonth) {
      return AppColors.hover;
    }

    return switch (widget.day) {
      _ when widget.day.isBlocked => AppColors.neutralGround,
      _ when widget.day.isRepriced => AppColors.infoGround,
      _ when _isHovered => AppColors.hover,
      _ => AppColors.surface,
    };
  }
}

class _Told extends StatelessWidget {
  const _Told({required this.day, required this.child});

  final AvailabilityDay day;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final List<String> lines = <String>[
      if (day.entry case final AccommodationAvailability entry)
        AvailabilityWords.entry(entry),
      if (day.booking case final Reservation booking) ..._booking(booking),
    ];

    return lines.isEmpty
        ? child
        : Tooltip(message: lines.join('\n'), child: child);
  }

  static List<String> _booking(Reservation booking) {
    final List<String> said = <String>[
      '${booking.guestName} · ${booking.status}',
    ];

    if (booking.stay case (final DateTime arrival, final DateTime departure)) {
      said.add('${AppDates.day(arrival)} to ${AppDates.day(departure)}');
    }

    return said..add(
      '${booking.guestCount} '
      '${booking.guestCount == 1 ? 'guest' : 'guests'}',
    );
  }
}

class _Number extends StatelessWidget {
  const _Number({required this.day});

  final AvailabilityDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizes.calendarDay,
      height: AppSizes.calendarDay,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: day.isToday ? AppColors.indigo : null,
        shape: BoxShape.circle,
      ),
      child: Text(
        '${day.date.day}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: _ink),
      ),
    );
  }

  Color get _ink {
    if (day.isToday) {
      return AppColors.surface;
    }

    return day.isInMonth ? AppColors.ink : AppColors.inkFaint;
  }
}

// Blocked days are hatched rather than only tinted, so the calendar still says
// which days are shut where a tint is the one thing a reader cannot see.
class _Hatching extends CustomPainter {
  const _Hatching();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = AppSizes.hairline;

    for (double x = -size.height; x < size.width; x += AppSpacing.sm) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(_Hatching oldDelegate) => false;
}
