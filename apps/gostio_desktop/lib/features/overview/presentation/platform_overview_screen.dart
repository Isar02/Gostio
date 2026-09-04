import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/overview_repository.dart';
import '../data/platform_overview.dart';
import 'overview_bookings.dart';
import 'overview_figures.dart';
import 'overview_panel.dart';
import 'overview_ranking.dart';
import 'overview_requests.dart';
import 'overview_trend.dart';
import 'platform_overview_notifier.dart';

class PlatformOverviewScreen extends StatelessWidget {
  const PlatformOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PlatformOverviewNotifier>(
      create: (BuildContext context) {
        final PlatformOverviewNotifier overview = PlatformOverviewNotifier(
          context.read<OverviewRepository>(),
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
    final PlatformOverviewNotifier overview = context
        .watch<PlatformOverviewNotifier>();
    final PlatformOverview? standing = overview.standing;

    if (standing == null) {
      return _Nothing(overview: overview);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Figures(standing: standing),
          const SizedBox(height: AppSpacing.lg),
          _Trade(standing: standing),
          const SizedBox(height: AppSpacing.lg),
          _Queues(standing: standing),
        ],
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.overview});

  final PlatformOverviewNotifier overview;

  @override
  Widget build(BuildContext context) {
    if (overview.failureMessage case final String failure) {
      return ErrorState(
        message: failure,
        onRetry: overview.reload,
        traceId: overview.failureTraceId,
      );
    }

    return const LoadingState(message: 'Reading the platform');
  }
}

class _Figures extends StatelessWidget {
  const _Figures({required this.standing});

  final PlatformOverview standing;

  @override
  Widget build(BuildContext context) {
    return OverviewFigures(<OverviewFigure>[
      OverviewFigure(
        label: 'Accounts',
        value: '${standing.users}',
        icon: Icons.people_outline,
      ),
      OverviewFigure(
        label: 'Listings published',
        value: '${standing.listings}',
        icon: Icons.apartment_outlined,
      ),
      OverviewFigure(
        label: 'Bookings this month',
        value: '${standing.bookingsThisMonth}',
        icon: Icons.event_available_outlined,
      ),
      OverviewFigure(
        label: 'Net this month',
        value: AppNumbers.money(standing.netThisMonth),
        icon: Icons.payments_outlined,
      ),
    ]);
  }
}

// The year reads widest and the places it happened stand beside it.
class _Trade extends StatelessWidget {
  const _Trade({required this.standing});

  final PlatformOverview standing;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: _trendShare,
            child: OverviewPanel(
              title: 'The year in net revenue',
              caption: 'Month by month, against its own best month',
              child: SizedBox(
                height: AppSizes.overviewChart,
                child: OverviewTrend(
                  months: standing.trade,
                  today: CalendarDays.today(),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            flex: _rankingShare,
            child: OverviewPanel(
              title: 'Where it happened',
              child: SizedBox(
                height: AppSizes.overviewChart,
                child: OverviewRanking(destinations: standing.destinations),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const int _trendShare = 3;
  static const int _rankingShare = 2;
}

class _Queues extends StatelessWidget {
  const _Queues({required this.standing});

  final PlatformOverview standing;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: OverviewPanel(
              title: 'The latest bookings',
              child: SizedBox(
                height: AppSizes.overviewList,
                child: OverviewBookings(bookings: standing.latestBookings),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: OverviewPanel(
              title: 'Waiting to host',
              // The few shown are not necessarily all there are.
              caption: standing.waitingCount > standing.waiting.length
                  ? '${standing.waitingCount} waiting in all'
                  : null,
              child: SizedBox(
                height: AppSizes.overviewList,
                child: OverviewRequests(requests: standing.waiting),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
