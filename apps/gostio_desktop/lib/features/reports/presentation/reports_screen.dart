import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/screen_states.dart';
import '../data/report_scope.dart';
import '../data/reports_repository.dart';
import 'report_filters.dart';
import 'report_printing.dart';
import 'reports_notifier.dart';
import 'shown_report.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({required this.scope, super.key});

  final ReportScope scope;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReportsNotifier>(
      create: (BuildContext context) {
        final ReportsNotifier reports = ReportsNotifier(
          context.read<ReportsRepository>(),
          scope: scope,
        );
        unawaited(reports.reload());

        return reports;
      },
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final ReportsNotifier reports = context.watch<ReportsNotifier>();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ReportFilters(
            kind: reports.kind,
            range: reports.range,
            catalogue: reports.catalogue,
            onShowReport: reports.showReport,
            onApplyRange: reports.applyRange,
            onApplyCatalogue: reports.applyCatalogue,
            trailing: const _Actions(),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: AppSizes.stroke,
            child: reports.isLoading ? const LinearProgressIndicator() : null,
          ),
          Expanded(child: _Document(reports: reports)),
        ],
      ),
    );
  }
}

class _Document extends StatelessWidget {
  const _Document({required this.reports});

  final ReportsNotifier reports;

  @override
  Widget build(BuildContext context) {
    final ShownReport<Object?, Object?>? shown = ShownReport.of(reports);

    return shown == null
        ? _Nothing(reports: reports)
        : shown.table(empty: const _Quiet());
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing({required this.reports});

  final ReportsNotifier reports;

  @override
  Widget build(BuildContext context) {
    if (reports.isLoading) {
      return const LoadingState(message: 'Building the report');
    }

    // Which date is wrong is said under that date.
    if (!reports.range.isAskable) {
      return const EmptyState(
        title: 'Nothing to build yet',
        message: 'The dates above do not make a range a report can cover.',
      );
    }

    if (reports.failureMessage case final String failure) {
      return ErrorState(
        message: failure,
        onRetry: reports.reload,
        traceId: reports.failureTraceId,
      );
    }

    return const LoadingState();
  }
}

class _Quiet extends StatelessWidget {
  const _Quiet();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      title: 'Nothing was booked',
      message: 'No booking in this range answers the report.',
    );
  }
}

// Both buttons render the same document, so either running holds the other.
enum _Action {
  save('Save as PDF', 'Saving', Icons.file_download_outlined, isPrimary: false),
  print('Print', 'Printing', Icons.print_outlined, isPrimary: true);

  const _Action(
    this.label,
    this.busyLabel,
    this.icon, {
    required this.isPrimary,
  });

  final String label;
  final String busyLabel;
  final IconData icon;
  final bool isPrimary;
}

class _Actions extends StatefulWidget {
  const _Actions();

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  _Action? _running;

  @override
  Widget build(BuildContext context) {
    final ReportsNotifier reports = context.watch<ReportsNotifier>();
    final ShownReport<Object?, Object?>? shown = ShownReport.of(reports);
    final bool isReady = shown != null && !reports.isLoading;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final _Action action in _Action.values) ...<Widget>[
          if (action != _Action.values.first)
            const SizedBox(width: AppSpacing.sm),
          _Button(
            action: action,
            running: _running,
            isReady: isReady,
            onPressed: () => _render(reports, shown, action),
          ),
        ],
      ],
    );
  }

  Future<void> _render(
    ReportsNotifier reports,
    ShownReport<Object?, Object?>? shown,
    _Action action,
  ) async {
    if (shown == null) {
      return;
    }

    final String name = ReportPrinting.nameFor(reports);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _running = action);

    try {
      final Uint8List bytes = await shown.printable(scope: reports.scope.label);

      if (action == _Action.save) {
        final Uri? written = await ReportPrinting.toFile(bytes, name: name);
        if (written != null) {
          messenger.showSnackBar(SnackBar(content: Text('$name was saved.')));
        }
      } else {
        await ReportPrinting.toPrinter(bytes, name: name);
      }
    } on Exception catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(_failureText(failure, action))),
      );
    }

    if (mounted) {
      setState(() => _running = null);
    }
  }

  static String _failureText(Exception failure, _Action action) =>
      switch (failure) {
        final ApiException refused => refused.message,
        _ =>
          action == _Action.save
              ? 'The report could not be saved.'
              : 'The report could not be sent to a printer.',
      };
}

// The one working says so, and one out of reach says why it is.
class _Button extends StatelessWidget {
  const _Button({
    required this.action,
    required this.running,
    required this.isReady,
    required this.onPressed,
  });

  final _Action action;
  final _Action? running;
  final bool isReady;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool isRunning = running == action;
    final bool canPress = isReady && running == null;
    final VoidCallback? pressed = canPress ? onPressed : null;
    final Widget icon = isRunning
        ? const SizedBox(
            width: AppSizes.iconSmall,
            height: AppSizes.iconSmall,
            child: CircularProgressIndicator(strokeWidth: AppSizes.stroke),
          )
        : Icon(action.icon, size: AppSizes.iconSmall);
    final Text label = Text(isRunning ? action.busyLabel : action.label);

    final Widget button = action.isPrimary
        ? FilledButton.icon(onPressed: pressed, icon: icon, label: label)
        : OutlinedButton.icon(onPressed: pressed, icon: icon, label: label);

    if (canPress || isRunning) {
      return button;
    }

    return Tooltip(
      message: isReady
          ? 'The report is being rendered.'
          : 'There is no report to save or print yet.',
      child: button,
    );
  }
}
