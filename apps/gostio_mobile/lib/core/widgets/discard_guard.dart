import 'package:flutter/material.dart';

import 'confirmation_dialog.dart';

// Back is the system gesture and the arrow in the bar, and both leave with
// what was typed. A form that still holds something asks first.
class DiscardGuard extends StatelessWidget {
  const DiscardGuard({required this.hasInput, required this.child, super.key});

  final bool hasInput;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !hasInput,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }

        final NavigatorState navigator = Navigator.of(context);
        final bool leaving = await ConfirmationDialog.ask(
          context,
          title: 'Leave this form?',
          message: 'What you have typed will not be kept.',
          confirmLabel: 'Leave',
          cancelLabel: 'Keep editing',
        );

        if (leaving && navigator.mounted) {
          navigator.pop();
        }
      },
      child: child,
    );
  }
}
