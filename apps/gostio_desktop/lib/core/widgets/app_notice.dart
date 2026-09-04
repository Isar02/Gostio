import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

class AppNotice extends StatelessWidget {
  const AppNotice(this.message, {this.tone = Tone.negative, super.key});

  final String message;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: tone.ground,
        borderRadius: AppRadii.medium,
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: tone.foreground),
      ),
    );
  }
}
