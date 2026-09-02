import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

class MultiSelectField<T extends Object> extends StatelessWidget {
  const MultiSelectField({
    required this.values,
    required this.selected,
    required this.labels,
    required this.onChanged,
    this.emptyLabel = 'Any',
    this.width = AppSizes.filterField,
    this.label,
    this.errorText,
    super.key,
  });

  final List<T> values;
  final Set<T> selected;
  final String Function(T value) labels;
  final ValueChanged<Set<T>> onChanged;
  final String emptyLabel;
  final double width;
  final String? label;
  final String? errorText;

  void _toggle(T value) {
    final Set<T> chosen = Set<T>.of(selected);
    if (!chosen.remove(value)) {
      chosen.add(value);
    }

    onChanged(chosen);
  }

  String get _label => switch (selected.length) {
    0 => emptyLabel,
    1 => labels(selected.first),
    _ => '${selected.length} selected',
  };

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: <Widget>[
        // A column rather than a lazy list: the menu measures its child's
        // intrinsic width, which a shrink-wrapped viewport cannot answer.
        SizedBox(
          width: width,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: AppSizes.panelHeight),
            // The menu is an overlay and never the page being scrolled, so it
            // keeps a controller of its own rather than adopting the primary
            // one the screen behind it is already using.
            child: SingleChildScrollView(
              primary: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final T value in values)
                    _Option<T>(
                      label: labels(value),
                      isSelected: selected.contains(value),
                      onTap: () => _toggle(value),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
      builder: (BuildContext context, MenuController menu, Widget? child) =>
          InkWell(
            onTap: values.isEmpty
                ? null
                : () => menu.isOpen ? menu.close() : menu.open(),
            borderRadius: AppRadii.medium,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                errorText: errorText,
                floatingLabelBehavior: FloatingLabelBehavior.always,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: selected.isEmpty
                            ? AppColors.inkMuted
                            : AppColors.ink,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
    );
  }
}

class _Option<T> extends StatelessWidget {
  const _Option({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: AppColors.hover,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            Checkbox(
              value: isSelected,
              visualDensity: VisualDensity.compact,
              onChanged: (bool? _) => onTap(),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
