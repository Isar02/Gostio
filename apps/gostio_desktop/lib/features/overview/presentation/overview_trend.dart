import 'package:flutter/material.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/formatting/app_numbers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../../reports/data/revenue_report.dart';

// The rolling year, month by month, drawn against its own best month. The
// figure is the net rather than what was charged, for the reason the tile above
// it is: a refund that went back was never earned.
class OverviewTrend extends StatelessWidget {
  const OverviewTrend({required this.months, required this.today, super.key});

  final List<RevenueReportRow> months;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final double peak = months.fold(
      0,
      (double best, RevenueReportRow row) => row.net > best ? row.net : best,
    );

    if (months.isEmpty || peak <= 0) {
      return const EmptyState(
        title: 'Nothing traded yet',
        message: 'A month with money in it draws a bar here.',
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final RevenueReportRow month in months)
                  Expanded(
                    child: _Bar(
                      month: month,
                      peak: peak,
                      isCurrent: _isCurrent(month),
                    ),
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

class _Bar extends StatelessWidget {
  const _Bar({
    required this.month,
    required this.peak,
    required this.isCurrent,
  });

  final RevenueReportRow month;
  final double peak;
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
        child: FractionallySizedBox(
          alignment: Alignment.bottomCenter,
          widthFactor: 1,
          // A month with nothing in it keeps a tick on the baseline, so the
          // reader can see it was answered rather than left out.
          heightFactor: (month.net / peak).clamp(_baseline, 1),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.indigo : AppColors.iris,
              borderRadius: const BorderRadius.vertical(
                top: AppRadii.smallRadius,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static const double _baseline = 0.015;
}
