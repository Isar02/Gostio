import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';

// One place the profile leads. The arrow is the only thing on it that is not
// words, because a row of a profile is read rather than scanned.
class ProfileLink extends StatelessWidget {
  const ProfileLink({
    required this.title,
    required this.message,
    required this.onTap,
    super.key,
  });

  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      semanticLabel: '$title. $message',
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ],
      ),
    );
  }
}
