import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/status_chip.dart';

// One term of an experience: when it begins, how long it runs and how many
// places it has left. A term nobody may take says which of the two reasons it
// is, because *full* and *you are already on this one* are answered by
// different things and only one of them is about the reader.
class TermCard extends StatelessWidget {
  const TermCard({
    required this.term,
    required this.isChosen,
    required this.isHeld,
    this.onChosen,
    super.key,
  });

  final ExperienceSlot term;
  final bool isChosen;

  // The reader already holds a place on this term. A guest holds one and no
  // more, so it is drawn as theirs rather than offered again.
  final bool isHeld;

  final VoidCallback? onChosen;

  bool get _isFull => term.remainingCapacity < 1;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AppCard(
      onTap: onChosen,
      isSelected: isChosen,
      semanticLabel: _spoken,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(AppDates.dateTime(term.startTime), style: text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  AppDurations.inWords(term.durationMinutes),
                  style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _standing(text),
        ],
      ),
    );
  }

  Widget _standing(TextTheme text) {
    if (isHeld) {
      return const StatusChip('Yours', tone: Tone.informative);
    }

    if (_isFull) {
      return const StatusChip('Full');
    }

    return Text(
      '${AppNumbers.counted(term.remainingCapacity, 'place')} left',
      style: text.bodyMedium,
    );
  }

  String get _spoken {
    final StringBuffer spoken = StringBuffer(AppDates.dateTime(term.startTime))
      ..write(', ${AppDurations.inWords(term.durationMinutes)}');

    if (isHeld) {
      spoken.write(', you already hold a place');
    } else if (_isFull) {
      spoken.write(', full');
    } else {
      spoken.write(
        ', ${AppNumbers.counted(term.remainingCapacity, 'place')} left',
      );
    }

    return spoken.toString();
  }
}
