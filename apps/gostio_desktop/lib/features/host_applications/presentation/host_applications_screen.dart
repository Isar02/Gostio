import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/pagination_footer.dart';
import '../../../core/widgets/record_table.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/host_application.dart';
import '../data/host_applications_repository.dart';
import 'application_standing.dart';
import 'host_application_detail_screen.dart';
import 'host_application_filters.dart';
import 'host_applications_notifier.dart';

class HostApplicationsScreen extends StatelessWidget {
  const HostApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HostApplicationsNotifier>(
      create: (BuildContext context) {
        final HostApplicationsNotifier applications = HostApplicationsNotifier(
          context.read<HostApplicationsRepository>(),
        );
        unawaited(applications.reload());

        return applications;
      },
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final HostApplicationsNotifier applications = context
        .watch<HostApplicationsNotifier>();
    final String? failure = applications.failureMessage;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HostApplicationFilters(
            applied: applications.query,
            isLoading: applications.isLoading,
            onChanged: applications.apply,
          ),
          if (failure != null && applications.items.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(failure),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.stroke,
            child: applications.isLoading
                ? const LinearProgressIndicator()
                : null,
          ),
          Expanded(
            child: RecordTable<HostApplication>(
              columns: _columns,
              rows: applications.items,
              onRowOpen: (HostApplication row) =>
                  _open(context, applications, row.id),
              empty: _Nothing(applications: applications),
              footer: PaginationFooter(
                page: applications.page,
                pageSize: applications.pageSize,
                totalCount: applications.totalCount,
                onPageChanged: applications.openPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Nothing is created here: the guest applies. The list reloads only when
  // the detail hands one back that has been answered.
  Future<void> _open(
    BuildContext context,
    HostApplicationsNotifier applications,
    int id,
  ) async {
    final HostApplication? answered = await Navigator.of(context)
        .push<HostApplication>(
          MaterialPageRoute<HostApplication>(
            builder: (BuildContext context) =>
                HostApplicationDetailScreen(applicationId: id),
          ),
        );

    if (answered != null) {
      await applications.reload();
    }
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.applications});

  final HostApplicationsNotifier applications;

  @override
  Widget build(BuildContext context) {
    if (applications.isLoading) {
      return const LoadingState();
    }

    if (applications.failureMessage case final String failure) {
      return ErrorState(
        message: failure,
        onRetry: applications.reload,
        traceId: applications.failureTraceId,
      );
    }

    return applications.query.isEmpty
        ? const EmptyState(
            title: 'No applications',
            message:
                'Requests appear here as guests ask to host. Nobody is put '
                'forward from this side.',
          )
        : const EmptyState(
            title: 'Nothing matches',
            message: 'No request stands where the filter above is set.',
          );
  }
}

// The two names read longest and are read as one group.
const int _nameShare = 3;
const int _usernameShare = 2;

final List<TableColumn<HostApplication>> _columns =
    <TableColumn<HostApplication>>[
      TableColumn<HostApplication>.text(
        label: 'Applicant',
        read: (HostApplication row) => row.applicantName,
        flex: _nameShare,
      ),
      TableColumn<HostApplication>.text(
        label: 'Username',
        read: (HostApplication row) => row.username,
        flex: _usernameShare,
      ),
      TableColumn<HostApplication>(
        label: 'Status',
        width: AppSizes.statusColumn,
        cell: (BuildContext context, HostApplication row) => StatusChip(
          row.status,
          tone: ApplicationStanding.toneOf(row.standing),
        ),
      ),
      TableColumn<HostApplication>.text(
        label: 'Applied',
        read: (HostApplication row) => AppDates.date(row.submittedAt),
        width: AppSizes.dateColumn,
      ),
      TableColumn<HostApplication>.text(
        label: 'Answered by',
        read: (HostApplication row) => row.reviewedByName ?? '—',
        flex: _usernameShare,
      ),
      TableColumn<HostApplication>.text(
        label: 'Answered',
        read: _answeredOn,
        width: AppSizes.dateColumn,
      ),
    ];

String _answeredOn(HostApplication row) => switch (row.reviewedAt) {
  final DateTime answered => AppDates.date(answered),
  null => '—',
};
