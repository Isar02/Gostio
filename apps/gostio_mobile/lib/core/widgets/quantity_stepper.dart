import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// A whole number chosen with a thumb rather than typed. What it counts is
// small and bounded — the people coming on a booking — so the two ends are
// reached by pressing rather than by clearing a field and typing over it.
//
// A step that would leave the range is not offered. The value itself is the
// caller's: this draws the number it was given and answers with the next one.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
    this.detail,
    super.key,
  });

  final String label;
  final String? detail;
  final int value;
  final int minimum;
  final int maximum;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(label, style: text.titleSmall),
                if (detail case final String detail) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    detail,
                    style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ],
            ),
          ),
          _Step(
            icon: Icons.remove_rounded,
            tooltip: 'One fewer',
            onPressed: value > minimum ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: AppSizes.touchTarget,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
          ),
          _Step(
            icon: Icons.add_rounded,
            tooltip: 'One more',
            onPressed: value < maximum ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.tooltip, this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      onPressed: onPressed,
      tooltip: tooltip,
      iconSize: AppSizes.iconSmall,
      constraints: const BoxConstraints.tightFor(
        width: AppSizes.touchTarget,
        height: AppSizes.touchTarget,
      ),
      icon: Icon(icon),
    );
  }
}
