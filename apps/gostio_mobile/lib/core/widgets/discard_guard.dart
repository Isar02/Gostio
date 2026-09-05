import 'package:flutter/material.dart';

import 'confirmation_dialog.dart';

// What a guard was answered, sent up the tree. `maybePop` tells a route it may
// refuse and then reports the same `true` whether it left or stayed, so
// whatever asked for the pop cannot learn the answer from the call it made.
//
// Anything driving more than one pop has to hear this: without it a gesture
// that empties a stack stops at the first question and never finishes the job
// the reader said yes to.
class DiscardAnswered extends Notification {
  const DiscardAnswered({required this.isLeaving});

  final bool isLeaving;
}

// Back is the system gesture, the arrow in the bar and the cross on a sheet,
// and all three leave with what was held. A surface that still holds something
// asks first.
//
// What is being left is named by the caller, because what a reader loses on a
// form and what they lose on a sheet of filters are not the same thing.
class DiscardGuard extends StatelessWidget {
  const DiscardGuard({
    required this.hasInput,
    required this.child,
    this.title = 'Leave this form?',
    this.message = 'What you have typed will not be kept.',
    super.key,
  });

  final bool hasInput;
  final String title;
  final String message;
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
          title: title,
          message: message,
          confirmLabel: 'Leave',
          cancelLabel: 'Keep editing',
        );

        if (leaving && navigator.mounted) {
          navigator.pop();
        }

        // Sent after the pop rather than before it, so whatever carries on
        // from here finds this route already gone.
        if (context.mounted) {
          DiscardAnswered(isLeaving: leaving).dispatch(context);
        }
      },
      child: child,
    );
  }
}
