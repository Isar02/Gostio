import 'package:flutter/material.dart';

import '../theme/app_metrics.dart';

class TimeField extends StatelessWidget {
  const TimeField({
    required this.value,
    required this.onChanged,
    this.label,
    this.hint = 'Any time',
    this.errorText,
    super.key,
  });

  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onChanged;
  final String? label;
  final String hint;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final TimeOfDay? chosen = value;

    return InkWell(
      onTap: () => _pick(context),
      borderRadius: AppRadii.medium,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: const Icon(
            Icons.schedule_outlined,
            size: AppSizes.iconSmall,
          ),
        ),
        child: Text(
          chosen == null ? hint : _written(context, chosen),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: value ?? const TimeOfDay(hour: 9, minute: 0),
    );

    if (picked != null) {
      onChanged(picked);
    }
  }

  // On a 24 hour clock, which is how every other moment in this client reads.
  static String _written(BuildContext context, TimeOfDay time) =>
      MaterialLocalizations.of(context)
          .formatTimeOfDay(time, alwaysUse24HourFormat: true);
}
