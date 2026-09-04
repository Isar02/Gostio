import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../data/host_applications_repository.dart';
import 'application_standing.dart';
import 'decide_application_dialog.dart';
import 'host_application_detail_notifier.dart';

class HostApplicationDetailScreen extends StatelessWidget {
  const HostApplicationDetailScreen({required this.applicationId, super.key});

  final int applicationId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HostApplicationDetailNotifier>(
      create: (BuildContext context) {
        final HostApplicationDetailNotifier notifier =
            HostApplicationDetailNotifier(
              context.read<HostApplicationsRepository>(),
              applicationId: applicationId,
            );
        unawaited(notifier.load());

        return notifier;
      },
      child: const _Detail(),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail();

  @override
  Widget build(BuildContext context) {
    final HostApplicationDetailNotifier notifier = context
        .watch<HostApplicationDetailNotifier>();
    final HostApplication? request = notifier.application;

    if (request == null) {
      if (notifier.isLoading) {
        return const LoadingState(message: 'Reading the application');
      }

      return ErrorState(
        message:
            notifier.failureMessage ?? 'This application could not be read.',
        onRetry: notifier.load,
        traceId: notifier.failureTraceId,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(notifier: notifier, request: request),
        SizedBox(
          height: AppSizes.stroke,
          child: notifier.isBusy
              ? const LinearProgressIndicator(minHeight: AppSizes.stroke)
              : null,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(child: _Applicant(request: request)),
                const SizedBox(width: AppSpacing.xl),
                Expanded(child: _Decision(request: request)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.notifier, required this.request});

  final HostApplicationDetailNotifier notifier;
  final HostApplication request;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          // A decision in flight has not said what it did yet, so leaving now
          // would hand the list a row that is about to be wrong.
          IconButton(
            onPressed: notifier.isWriting
                ? null
                : () =>
                      Navigator.of(context)
                          .pop(notifier.hasMoved ? request : null),
            icon: const Icon(Icons.arrow_back),
            tooltip: notifier.isWriting
                ? 'The decision being written has to land first.'
                : 'Back to the list',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  request.applicantName,
                  style: text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${request.username} · applied '
                  '${AppDates.date(request.submittedAt)}',
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          StatusChip(
            request.status,
            tone: ApplicationStanding.toneOf(request.standing),
          ),
          const SizedBox(width: AppSpacing.lg),
          _Moves(notifier: notifier, request: request),
        ],
      ),
    );
  }
}

class _Moves extends StatelessWidget {
  const _Moves({required this.notifier, required this.request});

  final HostApplicationDetailNotifier notifier;
  final HostApplication request;

  @override
  Widget build(BuildContext context) {
    final HostApplicationStatus? standing = request.standing;
    final bool isOpen = (standing?.canBeDecided ?? false) && !notifier.isBusy;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Tooltip(
          message: _approveMeans(standing),
          child: FilledButton(
            onPressed: isOpen
                ? () => _decide(context, ApplicationDecision.approve)
                : null,
            child: Text(notifier.isWriting ? 'Writing' : 'Approve'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Tooltip(
          message: _rejectMeans(standing),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: isOpen
                ? () => _decide(context, ApplicationDecision.reject)
                : null,
            child: const Text('Turn down'),
          ),
        ),
      ],
    );
  }

  static String _approveMeans(HostApplicationStatus? standing) =>
      switch (standing) {
        HostApplicationStatus.pending =>
          'Give this account the Host role and tell them.',
        HostApplicationStatus.approved => 'This request is already approved.',
        HostApplicationStatus.rejected =>
          'This request has already been turned down.',
        null =>
          'This request is in a standing this client does not answer it from.',
      };

  static String _rejectMeans(HostApplicationStatus? standing) =>
      switch (standing) {
        HostApplicationStatus.pending =>
          'Turn this request down and tell them why.',
        HostApplicationStatus.approved =>
          'An approved request cannot be turned down.',
        HostApplicationStatus.rejected =>
          'This request is already turned down.',
        null =>
          'This request is in a standing this client does not answer it from.',
      };

  Future<void> _decide(BuildContext context, ApplicationDecision decision) =>
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => DecideApplicationDialog(
          application: request,
          decision: decision,
          decide: (String reason) => switch (decision) {
            ApplicationDecision.approve => notifier.approve(
              reason: reason.isEmpty ? null : reason,
            ),
            ApplicationDecision.reject => notifier.reject(reason: reason),
          },
        ),
      );
}

class _Applicant extends StatelessWidget {
  const _Applicant({required this.request});

  final HostApplication request;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'The applicant',
      children: <Widget>[
        Row(
          children: <Widget>[
            AccountAvatar(userId: request.userId, name: request.applicantName),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                request.applicantName,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Fact('Username', request.username),
        _Fact('Applied', AppDates.dateTime(request.submittedAt)),
      ],
    );
  }
}

class _Decision extends StatelessWidget {
  const _Decision({required this.request});

  final HostApplication request;

  @override
  Widget build(BuildContext context) {
    if (!request.isAnswered) {
      return const _Panel(
        title: 'The decision',
        children: <Widget>[_Nothing('Nobody has answered this yet.')],
      );
    }

    return _Panel(
      title: 'The decision',
      children: <Widget>[
        Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(
            request.status,
            tone: ApplicationStanding.toneOf(request.standing),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _Fact('Answered by', request.reviewedByName ?? 'An account since gone'),
        if (request.reviewedAt case final DateTime answered)
          _Fact('Answered', AppDates.dateTime(answered)),
        _Fact('Reason', request.decisionReason ?? 'None was given.'),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border, width: AppSizes.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _factLabel,
            child: Text(
              label,
              style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
            ),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColors.inkFaint),
    );
  }
}

// The longest label a panel carries, so both sides line up as one column.
const double _factLabel = 96;
