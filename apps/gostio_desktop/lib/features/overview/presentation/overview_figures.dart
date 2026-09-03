import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';

// One figure the panel opens with. Both panels read four, and which four is
// the only difference between them.
@immutable
class OverviewFigure {
  const OverviewFigure({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class OverviewFigures extends StatelessWidget {
  const OverviewFigures(this.figures, {super.key});

  final List<OverviewFigure> figures;

  @override
  Widget build(BuildContext context) {
    // A label that wraps must not make its tile taller than the ones beside
    // it, so the row is measured before it is laid out.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final OverviewFigure figure in figures) ...<Widget>[
            if (figure != figures.first) const SizedBox(width: AppSpacing.lg),
            Expanded(child: _Tile(figure: figure)),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.figure});

  final OverviewFigure figure;

  @override
  Widget build(BuildContext context) {
    final TextTheme type = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  figure.label.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: type.labelSmall,
                ),
              ),
              Icon(
                figure.icon,
                size: AppSizes.icon,
                color: AppColors.borderStrong,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            figure.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.headlineMedium,
          ),
        ],
      ),
    );
  }
}
