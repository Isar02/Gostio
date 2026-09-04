import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// What a row is, said in colour as well as in words. It answers no gesture:
// a status is read, never set from a list.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {this.tone = Tone.neutral, super.key});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: tone.ground,
        borderRadius: AppRadii.pill,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: tone.foreground),
      ),
    );
  }
}
