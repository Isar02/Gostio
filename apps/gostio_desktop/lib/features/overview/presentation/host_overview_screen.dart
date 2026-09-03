import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/formatting/app_numbers.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/time/calendar_days.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/host_overview.dart';
import '../data/overview_month.dart';
import '../data/overview_repository.dart';
import 'host_overview_notifier.dart';
import 'overview_figures.dart';
import 'overview_movements.dart';
import 'overview_panel.dart';
import 'overview_timeline.dart';

class HostOverviewScreen extends StatelessWidget {
  const HostOverviewScreen({required this.hostId, super.key});

  final int hostId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HostOverviewNotifier>(
      create: (BuildContext context) {
        final HostOverviewNotifier overview = HostOverviewNotifier(
          context.read<OverviewRepository>(),
          hostId: hostId,
        );
        unawaited(overview.reload());

        return overview;
      },
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final HostOverviewNotifier overview = context.watch<HostOverviewNotifier>();

    // A read that failed leaves nothing to read around, so the whole screen
    // says so rather than three panels each saying it separately.
    if (overview.failureMessage case final String failure
        when overview.calendar == null) {
      return ErrorState(
        message: failure,
        onRetry: overview.reload,
        traceId: overview.failureTraceId,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Figures(figures: overview.figures),
          const SizedBox(height: AppSpacing.lg),
          _Calendar(overview: overview),
          const SizedBox(height: AppSpacing.lg),
          _Movements(calendar: overview.calendar),
        ],
      ),
    );
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.figures});

  final HostOverview? figures;

  @override
  Widget build(BuildContext context) {
    final HostOverview? read = figures;

    return OverviewFigures(<OverviewFigure>[
      OverviewFigure(
        label: 'Accommodations',
        value: _count(read?.accommodations),
        icon: Icons.apartment_outlined,
      ),
      OverviewFigure(
        label: 'Experiences',
        value: _count(read?.experiences),
        icon: Icons.hiking_outlined,
      ),
      OverviewFigure(
        label: 'Bookings this month',
        value: _count(read?.bookingsThisMonth),
        icon: Icons.event_available_outlined,
      ),
      OverviewFigure(
        label: 'Earned this month',
        value: read == null ? _waiting : AppNumbers.money(read.netThisMonth),
        icon: Icons.payments_outlined,
      ),
    ]);
  }

  // A figure not read yet is a placeholder rather than a nought, which would
  // be a number the reader has no way of knowing is not one.
  static String _count(int? value) => value == null ? _waiting : '$value';

  static const String _waiting = '—';
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.overview});

  final HostOverviewNotifier overview;

  @override
  Widget build(BuildContext context) {
    final OverviewMonth? calendar = overview.calendar;

    return OverviewPanel(
      title: AppDates.month(overview.month),
      caption: calendar == null
          ? null
          : '${calendar.bookedNights} '
                '${calendar.bookedNights == 1 ? 'night' : 'nights'} booked',
      trailing: _Stepper(overview: overview),
      child: SizedBox(
        height: _heightOf(calendar),
        child: _Grid(overview: overview, calendar: calendar),
      ),
    );
  }

  // The grid is as tall as the listings it draws, plus the row of days over
  // them and the gutter under them; anything else is as tall as a designed
  // state needs to stand in the same place.
  static double _heightOf(OverviewMonth? calendar) =>
      calendar == null || calendar.hasNoListings
      ? AppSizes.overviewChart
      : (calendar.rows.length + 1) * AppSizes.timelineRow +
            AppSizes.timelineGutter;
}

class _Grid extends StatelessWidget {
  const _Grid({required this.overview, required this.calendar});

  final HostOverviewNotifier overview;
  final OverviewMonth? calendar;

  @override
  Widget build(BuildContext context) {
    final OverviewMonth? read = calendar;

    if (read == null) {
      return const LoadingState(message: 'Reading the month');
    }

    if (read.hasNoListings) {
      return const EmptyState(
        title: 'No listing to fill yet',
        message: 'A month appears here once you have something to let.',
      );
    }

    return OverviewTimeline(month: read, today: CalendarDays.today());
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.overview});

  final HostOverviewNotifier overview;

  @override
  Widget build(BuildContext context) {
    final bool canMove = !overview.isLoading;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!overview.isOnThisMonth)
          TextButton(
            onPressed: canMove ? overview.showThisMonth : null,
            child: const Text('This month'),
          ),
        IconButton(
          onPressed: canMove ? () => overview.moveBy(-1) : null,
          tooltip: 'The month before',
          icon: const Icon(Icons.chevron_left, size: AppSizes.icon),
        ),
        IconButton(
          onPressed: canMove ? () => overview.moveBy(1) : null,
          tooltip: 'The month after',
          icon: const Icon(Icons.chevron_right, size: AppSizes.icon),
        ),
      ],
    );
  }
}

class _Movements extends StatelessWidget {
  const _Movements({required this.calendar});

  final OverviewMonth? calendar;

  @override
  Widget build(BuildContext context) {
    final OverviewMonth? read = calendar;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: OverviewPanel(
              title: 'Arrivals',
              child: SizedBox(
                height: AppSizes.overviewList,
                child: OverviewMovements(
                  movements: read?.arrivals ?? const <OverviewMovement>[],
                  quiet: 'Nobody checks in this month.',
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: OverviewPanel(
              title: 'Departures',
              child: SizedBox(
                height: AppSizes.overviewList,
                child: OverviewMovements(
                  movements: read?.departures ?? const <OverviewMovement>[],
                  quiet: 'Nobody checks out this month.',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
