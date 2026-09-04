import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/formatting/app_numbers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../../reports/data/revenue_report.dart';

// The rolling year, month by month. The figure is the net rather than what was
// charged, for the reason the tile above it is: a refund that went back was
// never earned. A month that gave back more than it took is a net below
// nought, and it is drawn under the line rather than folded up above it.
class OverviewTrend extends StatelessWidget {
  const OverviewTrend({required this.months, required this.today, super.key});

  final List<RevenueReportRow> months;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final _Scale scale = _Scale.of(months);

    if (scale.isFlat) {
      return const EmptyState(
        title: 'Nothing traded yet',
        message: 'A month with money moving in it draws a bar here.',
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        children: <Widget>[
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _ZeroLine(scale: scale),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final RevenueReportRow month in months)
                      Expanded(
                        child: _Bar(
                          month: month,
                          scale: scale,
                          isCurrent: _isCurrent(month),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (final RevenueReportRow month in months)
                Expanded(
                  child: Text(
                    AppDates.shortMonth(month.monthStart),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: _isCurrent(month)
                          ? AppColors.indigo
                          : AppColors.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isCurrent(RevenueReportRow month) =>
      month.year == today.year && month.month == today.month;
}

// The room above nought and the room below it, measured once for the whole
// year so two months can be compared by length. Both halves are only drawn
// where the year has something on that side of the line.
@immutable
class _Scale {
  const _Scale._({required this.above, required this.below});

  factory _Scale.of(List<RevenueReportRow> months) {
    double best = 0;
    double worst = 0;

    for (final RevenueReportRow month in months) {
      best = math.max(best, month.net);
      worst = math.min(worst, month.net);
    }

    return _Scale._(above: best, below: worst);
  }

  // The best month, never below nought, and the worst, never above it.
  final double above;
  final double below;

  double get span => above - below;

  // A year in which every month is exactly nought has no length to draw with.
  bool get isFlat => span <= 0;

  bool get hasGains => above > 0;

  bool get hasLosses => below < 0;

  int get gainShare => _shareOf(above);

  int get lossShare => _shareOf(-below);

  // A month with nothing in it keeps a tick on the line, so the reader can see
  // it was answered rather than left out.
  static const double tick = 0.015;

  int _shareOf(double part) => math.max(1, (part / span * _precision).round());

  static const int _precision = 1000;
}

// A hairline where nought is, drawn behind the bars and taking no height of
// its own, so it sits exactly where the two halves meet.
class _ZeroLine extends StatelessWidget {
  const _ZeroLine({required this.scale});

  final _Scale scale;

  @override
  Widget build(BuildContext context) {
    if (!scale.hasGains || !scale.hasLosses) {
      return const SizedBox.shrink();
    }

    return Column(
      children: <Widget>[
        Expanded(flex: scale.gainShare, child: const SizedBox.expand()),
        Expanded(
          flex: scale.lossShare,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.borderStrong,
                  width: AppSizes.hairline,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.month,
    required this.scale,
    required this.isCurrent,
  });

  final RevenueReportRow month;
  final _Scale scale;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message:
          '${AppDates.month(month.monthStart)}\n'
          '${AppNumbers.money(month.net)}\n'
          '${month.bookingsCreated} '
          '${month.bookingsCreated == 1 ? 'booking' : 'bookings'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Column(
          children: <Widget>[
            if (scale.hasGains)
              Expanded(
                flex: scale.gainShare,
                child: _Half(
                  fraction: _above,
                  ink: _ink,
                  alignment: Alignment.bottomCenter,
                  corner: const BorderRadius.vertical(
                    top: AppRadii.smallRadius,
                  ),
                ),
              ),
            if (scale.hasLosses)
              Expanded(
                flex: scale.lossShare,
                child: _Half(
                  fraction: _below,
                  ink: _ink,
                  alignment: Alignment.topCenter,
                  corner: const BorderRadius.vertical(
                    bottom: AppRadii.smallRadius,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double get _above {
    if (month.net > 0) {
      return (month.net / scale.above).clamp(0, 1);
    }

    // A month of nothing keeps its tick above the line where there is a side
    // above it, and under the line where the whole year is below it.
    return month.net == 0 ? _Scale.tick : 0;
  }

  double get _below {
    if (month.net < 0) {
      return (month.net / scale.below).clamp(0, 1);
    }

    return month.net == 0 && !scale.hasGains ? _Scale.tick : 0;
  }

  // Which way the bar points says what the month did; the colour says the same
  // thing again, because a bar read alone is easy to read the wrong way up.
  Color get _ink {
    if (month.net < 0) {
      return isCurrent ? AppColors.dangerDeep : AppColors.danger;
    }

    return isCurrent ? AppColors.indigo : AppColors.iris;
  }
}

class _Half extends StatelessWidget {
  const _Half({
    required this.fraction,
    required this.ink,
    required this.alignment,
    required this.corner,
  });

  final double fraction;
  final Color ink;
  final Alignment alignment;
  final BorderRadius corner;

  @override
  Widget build(BuildContext context) {
    if (fraction <= 0) {
      return const SizedBox.expand();
    }

    // Both factors are given: the box sizes its child on the axis it has a
    // factor for and hands it a loose constraint on the other, and a painted
    // box has no size of its own to fill that with.
    return FractionallySizedBox(
      alignment: alignment,
      widthFactor: 1,
      heightFactor: fraction,
      child: DecoratedBox(
        decoration: BoxDecoration(color: ink, borderRadius: corner),
      ),
    );
  }
}
