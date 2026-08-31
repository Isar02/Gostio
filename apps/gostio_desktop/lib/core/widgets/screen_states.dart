import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: AppSizes.spinner,
            height: AppSizes.spinner,
            child: CircularProgressIndicator(strokeWidth: AppSizes.stroke),
          ),
          if (message case final String message) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(message, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.title, this.message, this.action, super.key});

  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _CentredMessage(title: title, message: message, action: action);
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.message,
    this.title = 'That did not work',
    this.onRetry,
    this.traceId,
    super.key,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;

  // The same id is in the server's log, so it is worth carrying out of here.
  final String? traceId;

  @override
  Widget build(BuildContext context) {
    return _CentredMessage(
      title: title,
      titleColour: AppColors.danger,
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      footnote: traceId,
    );
  }
}

class _CentredMessage extends StatelessWidget {
  const _CentredMessage({
    required this.title,
    this.message,
    this.action,
    this.titleColour,
    this.footnote,
  });

  final String title;
  final String? message;
  final Widget? action;
  final Color? titleColour;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.panel),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: titleColour),
              ),
              if (message case final String message) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                ),
              ],
              if (action case final Widget action) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                action,
              ],
              if (footnote case final String trace) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                SelectableText(
                  'Trace $trace',
                  style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
