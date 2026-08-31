import 'package:flutter/material.dart';

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    required this.value,
    required this.values,
    required this.labels,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<T> values;
  final String Function(T value) labels;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return _DropdownField<T>(
      value: value,
      items: <DropdownMenuItem<T>>[
        for (final T option in values)
          DropdownMenuItem<T>(value: option, child: Text(labels(option))),
      ],
      onChanged: (T? chosen) {
        if (chosen != null) {
          onChanged(chosen);
        }
      },
    );
  }
}

// The same control where choosing nothing is itself an answer, which a filter
// needs and a required field does not.
class AppOptionalDropdown<T extends Object> extends StatelessWidget {
  const AppOptionalDropdown({
    required this.value,
    required this.values,
    required this.labels,
    required this.onChanged,
    this.anyLabel = 'Any',
    super.key,
  });

  final T? value;
  final List<T> values;
  final String Function(T value) labels;
  final ValueChanged<T?> onChanged;
  final String anyLabel;

  @override
  Widget build(BuildContext context) {
    return _DropdownField<T?>(
      value: value,
      items: <DropdownMenuItem<T?>>[
        DropdownMenuItem<T?>(child: Text(anyLabel)),
        for (final T option in values)
          DropdownMenuItem<T?>(value: option, child: Text(labels(option))),
      ],
      onChanged: onChanged,
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: onChanged,
          items: items,
        ),
      ),
    );
  }
}
