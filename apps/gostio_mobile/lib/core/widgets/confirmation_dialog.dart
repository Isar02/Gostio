import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

abstract final class ConfirmationDialog {
  static Future<bool> ask(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
  }) async {
    final bool? answer = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => _ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );

    return answer ?? false;
  }
}

class _ConfirmationDialog extends StatelessWidget {
  const _ConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      actionsPadding: const EdgeInsets.all(AppSpacing.lg),
      content: Text(message),
      // One column rather than the row a dialog lays its actions out in:
      // stacked and the same width, a thumb reaching for the way out cannot
      // land on the act instead.
      actions: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            OutlinedButton(
              style: isDestructive ? null : _wayOut,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              style: isDestructive ? _destructive : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ],
    );
  }

  static final ButtonStyle _destructive = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.pressed)
          ? AppColors.dangerDeep
          : AppColors.danger,
    ),
  );

  // Red only where the act being agreed to is not: two red buttons say nothing.
  static final ButtonStyle _wayOut = ButtonStyle(
    foregroundColor: const WidgetStatePropertyAll<Color>(AppColors.danger),
    side: const WidgetStatePropertyAll<BorderSide>(
      BorderSide(color: AppColors.danger),
    ),
  );
}
