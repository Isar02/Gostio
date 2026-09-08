import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({
    required this.filters,
    this.onClear,
    this.trailing,
    this.crossAxisAlignment = WrapCrossAlignment.end,
    super.key,
  });

  final List<Widget> filters;
  final VoidCallback? onClear;
  final Widget? trailing;
  final WrapCrossAlignment crossAxisAlignment;

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
              crossAxisAlignment: crossAxisAlignment,
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
    this.errorText,
    super.key,
  });

  final String label;
  final Widget child;
  final double width;
  final String? errorText;

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
          // Every control is given the same height, or a bar of fields that
          // are naturally a few pixels apart hangs its labels on a ragged line.
          SizedBox(height: AppSizes.control, child: child),
          // Validation grows below the control without taking room from its value.
          if (errorText case final String error)
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.xs,
              ),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: Theme.of(context).inputDecorationTheme.errorStyle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Two fields that read as one range, kept together. The outer bar would
// otherwise leave "from" at the end of a row and "to" at the start of the next.
class FilterPair extends StatelessWidget {
  const FilterPair(this.from, this.to, {super.key});

  final Widget from;
  final Widget to;

  @override
  Widget build(BuildContext context) {
    // A wrap of its own rather than a row: on a bar too narrow for both, the
    // two stack under each other instead of running off the edge.
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: <Widget>[from, to],
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
