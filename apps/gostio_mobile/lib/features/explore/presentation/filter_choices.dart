import 'package:flutter/material.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_chip.dart';

// One of a set, or none of it. Tapping what is already chosen puts it back,
// which is the only way a sheet of chips can be emptied without a control
// that exists to say "no preference".
class PickOne<T extends Object> extends StatelessWidget {
  const PickOne({
    required this.options,
    required this.nameOf,
    required this.selected,
    required this.onChosen,
    super.key,
  });

  final List<T> options;
  final String Function(T option) nameOf;
  final T? selected;
  final ValueChanged<T?> onChosen;

  @override
  Widget build(BuildContext context) {
    return _ChipWrap(
      children: <Widget>[
        for (final T option in options)
          AppChip(
            nameOf(option),
            isSelected: option == selected,
            onTap: () => onChosen(option == selected ? null : option),
          ),
      ],
    );
  }
}

// Any of a set. Every named one has to be there rather than any of them, which
// is what the API does with the ids and what the group above this says.
class PickMany<T extends Object> extends StatelessWidget {
  const PickMany({
    required this.options,
    required this.nameOf,
    required this.chosen,
    required this.onChanged,
    super.key,
  });

  final List<T> options;
  final String Function(T option) nameOf;
  final List<T> chosen;
  final ValueChanged<List<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return _ChipWrap(
      children: <Widget>[
        for (final T option in options)
          AppChip(
            nameOf(option),
            isSelected: chosen.contains(option),
            onTap: () => onChanged(_toggled(option)),
          ),
      ],
    );
  }

  // The order the options were offered in, so a chip does not move to the end
  // of the row the moment it is chosen.
  List<T> _toggled(T option) => <T>[
    for (final T candidate in options)
      if (candidate == option
          ? !chosen.contains(option)
          : chosen.contains(candidate))
        candidate,
  ];
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpacing.sm,
    runSpacing: AppSpacing.sm,
    children: children,
  );
}
