import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import 'payment_notifier.dart';

// What is owed and the way to settle it. A booking the server calls paid is
// not offered a button at all, which is the one place this screen may not
// trust itself: the state comes off the booking rather than off the sheet.
class PayBar extends StatelessWidget {
  const PayBar({this.cancel, super.key});

  // Offered by the screen rather than decided here: what a booking may be told
  // is the booking's business, not the payment's.
  final Widget? cancel;

  @override
  Widget build(BuildContext context) {
    final PaymentNotifier payment = context.watch<PaymentNotifier>();

    // A booking that is paid for, or one that has ended without being paid
    // for, is not owed anything: there is no figure to carry and no button to
    // carry it beside.
    if (!payment.isOwed) {
      return cancel == null
          ? const SizedBox.shrink()
          : BottomActionBar(action: cancel!);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_notice(payment) case (final String message, final Tone tone))
          _PaymentNotice(message, tone: tone),
        BottomActionBar(
          above: cancel,
          label: AppNumbers.money(payment.booking.totalPrice),
          detail: payment.isPayable ? 'Due now' : null,
          action: FilledButton(
            onPressed: _action(context, payment),
            child: Text(_label(payment.stage)),
          ),
        ),
      ],
    );
  }

  (String, Tone)? _notice(PaymentNotifier payment) {
    if (payment.refusal case final String refusal) {
      return (refusal, Tone.negative);
    }

    return switch (payment.stage) {
      PaymentStage.confirming => (
        'Payment sent. Confirming it with the card processor.',
        Tone.informative,
      ),
      PaymentStage.unconfirmed => (
        'Payment sent, but no confirmation has reached us yet. Ask again in a '
            'moment, or open this booking from Trips later — nothing is '
            'charged twice.',
        Tone.attention,
      ),
      _ => null,
    };
  }

  String _label(PaymentStage stage) => switch (stage) {
    PaymentStage.idle => 'Pay',
    PaymentStage.opening => 'Opening',
    PaymentStage.confirming => 'Confirming',
    PaymentStage.unconfirmed => 'Ask again',
  };

  VoidCallback? _action(BuildContext context, PaymentNotifier payment) =>
      switch (payment.stage) {
        PaymentStage.idle when payment.isPayable => () => unawaited(
          _pay(context, payment),
        ),
        PaymentStage.unconfirmed => () => unawaited(payment.confirmAgain()),
        _ => null,
      };

  Future<void> _pay(BuildContext context, PaymentNotifier payment) async {
    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Pay for this booking?',
      message:
          'The card sheet opens next and takes '
          '${AppNumbers.money(payment.booking.totalPrice)} for '
          '${payment.booking.listingTitle}.',
      confirmLabel: 'Pay now',
    );

    if (agreed) {
      await payment.pay();
    }
  }
}

class _PaymentNotice extends StatelessWidget {
  const _PaymentNotice(this.message, {required this.tone});

  final String message;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          0,
        ),
        child: AppNotice(message, tone: tone),
      ),
    );
  }
}
