import 'package:flutter/material.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_dropdown.dart';
import '../data/lookup_item.dart';

// Adding a city is the administrator's route, so a host is offered the
// dropdown alone.
class CityField extends StatelessWidget {
  const CityField({
    required this.city,
    required this.cities,
    required this.errorText,
    required this.canAdd,
    required this.onChanged,
    required this.onAdd,
    super.key,
  });

  final LookupItem? city;
  final List<LookupItem> cities;
  final String? errorText;
  final bool canAdd;
  final ValueChanged<LookupItem?> onChanged;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final Widget field = AppOptionalDropdown<LookupItem>(
      label: 'City',
      anyLabel: 'Choose a city',
      errorText: errorText,
      value: city,
      values: cities,
      labels: (LookupItem city) => city.name,
      onChanged: onChanged,
    );

    if (!canAdd) {
      return field;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: field),
        const SizedBox(width: AppSpacing.sm),
        IconButton(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          tooltip: 'Add a city',
        ),
      ],
    );
  }
}
