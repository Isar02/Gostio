import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_metrics.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    required this.filters,
    this.onClear,
    this.trailing,
    super.key,
  });

  final List<Widget> filters;
  final VoidCallback? onClear;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border, width: AppSizes.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: <Widget>[
                ...filters,
                if (onClear case final VoidCallback clear)
                  SizedBox(
                    height: AppSizes.control,
                    child: TextButton(
                      onPressed: clear,
                      child: const Text('Clear'),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing case final Widget trailing) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            trailing,
          ],
        ],
      ),
    );
  }
}

class FilterField extends StatelessWidget {
  const FilterField({
    required this.label,
    required this.child,
    this.width = AppSizes.filterField,
    super.key,
  });

  final String label;
  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      ),
    );
  }
}

// A keystroke is not a request.
class FilterTextField extends StatefulWidget {
  const FilterTextField({
    required this.controller,
    required this.onChanged,
    this.onEdited,
    this.hint,
    this.formatters = const <TextInputFormatter>[],
    super.key,
  });

  static const Duration settle = Duration(milliseconds: 400);

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onEdited;
  final String? hint;
  final List<TextInputFormatter> formatters;

  @override
  State<FilterTextField> createState() => _FilterTextFieldState();
}

class _FilterTextFieldState extends State<FilterTextField> {
  Timer? _settling;

  void _typed(String value) {
    widget.onEdited?.call();
    _settling?.cancel();
    _settling = Timer(FilterTextField.settle, () => widget.onChanged(value));
  }

  void _submitted(String value) {
    _settling?.cancel();
    widget.onChanged(value);
  }

  @override
  void dispose() {
    _settling?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      inputFormatters: widget.formatters,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(hintText: widget.hint),
      onChanged: _typed,
      onSubmitted: _submitted,
    );
  }
}
