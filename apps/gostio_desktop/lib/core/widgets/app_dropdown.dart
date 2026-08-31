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
    return InputDecorator(
      decoration: const InputDecoration(),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          style: Theme.of(context).textTheme.bodyMedium,
          onChanged: (T? chosen) {
            if (chosen != null) {
              onChanged(chosen);
            }
          },
          items: <DropdownMenuItem<T>>[
            for (final T option in values)
              DropdownMenuItem<T>(value: option, child: Text(labels(option))),
          ],
        ),
      ),
    );
  }
}
