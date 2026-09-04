import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../theme/app_metrics.dart';

// A password typed on a phone keyboard is worth being able to read back, so
// every one of them carries the same reveal.
class PasswordField extends StatefulWidget {
  const PasswordField({
    required this.controller,
    required this.label,
    this.fieldKey,
    this.enabled = true,
    this.errorText,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final Key? fieldKey;
  final bool enabled;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _isHidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      key: widget.fieldKey,
      controller: widget.controller,
      obscureText: _isHidden,
      enabled: widget.enabled,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        errorText: widget.errorText,
        // Kept out of the traversal order: the field after this one is what
        // Next is asked for, not the eye inside it.
        suffixIcon: ExcludeFocus(
          child: IconButton(
            onPressed: () => setState(() => _isHidden = !_isHidden),
            icon: Icon(
              _isHidden
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.inkMuted,
              size: AppSizes.icon,
            ),
            tooltip: _isHidden ? 'Show the password' : 'Hide the password',
          ),
        ),
      ),
    );
  }
}
