import 'package:flutter/material.dart';

import '../formatting/app_dates.dart';
import '../theme/app_metrics.dart';

class DateField extends StatelessWidget {
  const DateField({
    required this.value,
    required this.onChanged,
    this.label,
    this.hint = 'Any day',
    this.errorText,
    this.firstDate,
    this.lastDate,
    this.isClearable = true,
    super.key,
  });

  static final DateTime _earliest = DateTime(2000);
  static final DateTime _latest = DateTime(2100);

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final String? label;
  final String hint;
  final String? errorText;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool isClearable;

  @override
  Widget build(BuildContext context) {
    final DateTime? chosen = value;

    return InkWell(
      onTap: () => _pick(context),
      borderRadius: AppRadii.medium,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          suffixIcon: chosen != null && isClearable
              ? IconButton(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close, size: AppSizes.iconSmall),
                  tooltip: 'Clear',
                )
              : const Icon(
                  Icons.calendar_today_outlined,
                  size: AppSizes.iconSmall,
                ),
        ),
        child: Text(
          chosen == null ? hint : AppDates.day(chosen),
          style: Theme.of(context).textTheme.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // The calendar refuses to open on a day outside the range it offers, and
  // today at midnight is before a range that begins at this moment.
  Future<void> _pick(BuildContext context) async {
    final DateTime first = firstDate ?? _earliest;
    final DateTime last = lastDate ?? _latest;
    DateTime opensOn = value ?? DateTime.now();

    if (opensOn.isBefore(first)) {
      opensOn = first;
    }
    if (opensOn.isAfter(last)) {
      opensOn = last;
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: opensOn,
      firstDate: first,
      lastDate: last,
    );

    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }
}
