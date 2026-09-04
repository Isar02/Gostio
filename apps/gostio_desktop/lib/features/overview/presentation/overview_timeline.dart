import 'package:flutter/material.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/time/calendar_days.dart';
import '../../listings/presentation/booking_colours.dart';
import '../../reservations/data/reservation.dart';
import '../data/overview_month.dart';

// A month across every listing a host owns. The names are pinned and the days
// scroll under them, so a title stays readable in a window narrow enough that
// thirty columns do not fit at a width a day number can be read at.
class OverviewTimeline extends StatelessWidget {
  const OverviewTimeline({required this.month, required this.today, super.key});

  final OverviewMonth month;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Names(rows: month.rows),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints room) {
              // A month wider than the room it has scrolls at the narrowest a
              // day may be; one that fits spreads over the room it has, so the
              // window this client is built for shows every day at once. The
              // width is whole pixels, or the rounding puts the last column a
              // hair past the edge and clips the day drawn in it.
              final double day = (room.maxWidth / month.days.length)
                  .floorToDouble()
                  .clamp(AppSizes.timelineDay, double.infinity);

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: month.days.length * day,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _Days(days: month.days, today: today, width: day),
                      for (final OverviewRow row in month.rows)
                        _Nights(
                          row: row,
                          days: month.days,
                          today: today,
                          width: day,
                        ),
                      const SizedBox(height: AppSizes.timelineGutter),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Names extends StatelessWidget {
  const _Names({required this.rows});

  final List<OverviewRow> rows;

  @override
  Widget build(BuildContext context) {
    final TextTheme type = Theme.of(context).textTheme;

    return SizedBox(
      width: AppSizes.timelineListing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: AppSizes.timelineRow,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            color: AppColors.hover,
            child: Text('Listing', style: type.labelSmall),
          ),
          for (final OverviewRow row in rows)
            Container(
              height: AppSizes.timelineRow,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.border,
                    width: AppSizes.hairline,
                  ),
                ),
              ),
              child: Tooltip(
                message: row.listing.name,
                child: Text(
                  row.listing.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.bodyMedium,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Days extends StatelessWidget {
  const _Days({required this.days, required this.today, required this.width});

  final List<DateTime> days;
  final DateTime today;
  final double width;

  @override
  Widget build(BuildContext context) {
    final TextTheme type = Theme.of(context).textTheme;

    return Container(
      height: AppSizes.timelineRow,
      color: AppColors.hover,
      child: Row(
        children: <Widget>[
          for (final DateTime day in days)
            SizedBox(
              width: width,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(AppDates.weekday(day), style: type.labelSmall),
                  Text(
                    '${day.day}',
                    style: type.labelMedium?.copyWith(
                      color: day == today ? AppColors.indigo : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// The days under a listing, with the stays laid over them. The bars share the
// columns with the cells rather than being measured in pixels, so a day and
// the night on it cannot come apart.
class _Nights extends StatelessWidget {
  const _Nights({
    required this.row,
    required this.days,
    required this.today,
    required this.width,
  });

  final OverviewRow row;
  final List<DateTime> days;
  final DateTime today;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.timelineRow,
      child: Stack(
        children: <Widget>[
          Row(
            children: <Widget>[
              for (final DateTime day in days)
                Container(
                  width: width,
                  decoration: BoxDecoration(
                    color: _groundOf(day),
                    border: const Border(
                      top: BorderSide(
                        color: AppColors.border,
                        width: AppSizes.hairline,
                      ),
                      right: BorderSide(
                        color: AppColors.border,
                        width: AppSizes.hairline,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            top: (AppSizes.timelineRow - AppSizes.timelineBar) / 2,
            height: AppSizes.timelineBar,
            child: _Bars(spans: row.spans, width: width),
          ),
        ],
      ),
    );
  }

  Color _groundOf(DateTime day) {
    if (day == today) {
      return AppColors.selected;
    }

    return day.weekday >= DateTime.saturday
        ? AppColors.hover
        : AppColors.surface;
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.spans, required this.width});

  final List<OverviewSpan> spans;
  final double width;

  @override
  Widget build(BuildContext context) {
    final List<Widget> laid = <Widget>[];
    int filled = 0;

    for (final OverviewSpan span in spans) {
      if (span.column > filled) {
        laid.add(SizedBox(width: (span.column - filled) * width));
      }

      laid.add(
        SizedBox(
          width: span.span * width,
          child: _Bar(span: span),
        ),
      );
      filled = span.column + span.span;
    }

    return Row(children: laid);
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.span});

  final OverviewSpan span;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _told,
      child: Container(
        margin: EdgeInsets.only(
          left: span.startsHere ? AppSpacing.xs : 0,
          right: span.endsHere ? AppSpacing.xs : 0,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: BookingColours.bar(span.booking.standing),
          borderRadius: BorderRadius.horizontal(
            left: span.startsHere ? AppRadii.smallRadius : Radius.zero,
            right: span.endsHere ? AppRadii.smallRadius : Radius.zero,
          ),
        ),
        child: Text(
          span.booking.guestName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: AppColors.surface),
        ),
      ),
    );
  }

  String get _told {
    final Reservation booking = span.booking;
    final List<String> lines = <String>[
      '${booking.guestName} · ${booking.status}',
    ];

    if (booking.stay case (final DateTime arrival, final DateTime leaving)) {
      lines.add('${AppDates.day(arrival)} to ${AppDates.day(leaving)}');
      lines.add(_nights(CalendarDays.daysBetween(arrival, leaving)));
    }

    return lines.join('\n');
  }

  static String _nights(int nights) =>
      '$nights ${nights == 1 ? 'night' : 'nights'}';
}
