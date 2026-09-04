import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';

// Calling a booking off cannot be undone, so the dialog is the confirmation:
// what happens, what goes back, and the reason the server demands.
class CancelReservationDialog extends StatefulWidget {
  const CancelReservationDialog({
    required this.reservation,
    required this.readQuote,
    required this.cancel,
    super.key,
  });

  final Reservation reservation;
  final Future<RefundQuote> Function() readQuote;
  final Future<ApiException?> Function({required String reason}) cancel;

  @override
  State<CancelReservationDialog> createState() =>
      _CancelReservationDialogState();
}

class _CancelReservationDialogState extends State<CancelReservationDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _reason = TextEditingController();

  bool _isSaving = false;
  bool _isQuoting = true;
  RefundQuote? _quote;
  ApiException? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_readQuote());
  }

  // The quote is what this costs, not what it does: a read that failed leaves
  // the cancellation on offer, because the server works the amount out itself.
  Future<void> _readQuote() async {
    RefundQuote? quote;

    try {
      quote = await widget.readQuote();
    } on ApiException {
      quote = null;
    }

    if (mounted) {
      setState(() {
        _quote = quote;
        _isQuoting = false;
      });
    }
  }

  @override
  void dispose() {
    _reason.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A refusal is said in this dialog, so it cannot be dismissed out from
    // under a write that is still running.
    return PopScope(canPop: !_isSaving, child: _dialog(context));
  }

  Widget _dialog(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text('Cancel this booking?', style: text.titleLarge),
      content: SizedBox(
        width: AppSizes.panel,
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _whatHappens,
                style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
              ),
              const SizedBox(height: AppSpacing.lg),
              _Owed(quote: _quote, isReading: _isQuoting),
              const SizedBox(height: AppSpacing.lg),
              if (_failure case final ApiException failure
                  when !failure.faultsAField) ...<Widget>[
                AppNotice(failure.message),
                const SizedBox(height: AppSpacing.lg),
              ],
              TextFormField(
                controller: _reason,
                enabled: !_isSaving,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  alignLabelWithHint: true,
                  helperText: 'The guest is told why.',
                  errorText: _failure?.firstMessageFor('reason'),
                ),
                validator: Validators.cancellationReason,
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.all(AppSpacing.lg),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Keep the booking'),
        ),
        const SizedBox(width: AppSpacing.sm),
        // What goes back is part of the decision, so the decision waits for it.
        FilledButton(
          style: _destructive,
          onPressed: _isSaving || _isQuoting ? null : _submit,
          child: Text(_isSaving ? 'Cancelling' : 'Cancel the booking'),
        ),
      ],
    );
  }

  // A stay gives dates back; a term gives places in the slot back.
  String get _whatHappens {
    final Reservation booking = widget.reservation;
    final String given = booking.isTerm
        ? 'What this booking holds in ${booking.listingTitle} goes back to '
              'the term'
        : '${booking.listingTitle} goes back on offer for these dates';

    return '$given and ${booking.guestName} is told. This cannot be undone.';
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _failure = null;
      _isSaving = true;
    });

    final ApiException? refused = await widget.cancel(
      reason: _reason.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (refused == null) {
      Navigator.of(context).pop();

      return;
    }

    setState(() {
      _failure = refused;
      _isSaving = false;
    });
  }

  static final ButtonStyle _destructive = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) =>
          states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)
          ? AppColors.dangerDeep
          : AppColors.danger,
    ),
  );
}

class _Owed extends StatelessWidget {
  const _Owed({required this.quote, required this.isReading});

  final RefundQuote? quote;
  final bool isReading;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    if (isReading) {
      return Text(
        'Reading what this sends back.',
        style: text.bodySmall?.copyWith(color: AppColors.inkFaint),
      );
    }

    if (quote case final RefundQuote owed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AppNotice(_amount(owed), tone: Tone.informative),
          const SizedBox(height: AppSpacing.sm),
          Text(
            owed.reason,
            style: text.bodySmall?.copyWith(color: AppColors.inkMuted),
          ),
        ],
      );
    }

    return const AppNotice(
      'What this sends back could not be read. The server works it out either '
      'way, so the cancellation still stands.',
      tone: Tone.attention,
    );
  }

  // A booking nobody paid for owes nothing back, whatever the policy works out.
  String _amount(RefundQuote owed) {
    if (!owed.isPaid) {
      return 'Nothing was charged for this booking, so nothing goes back.';
    }

    return '${AppNumbers.moneyIn(owed.amount, owed.currency)} of '
        '${AppNumbers.moneyIn(owed.charged, owed.currency)} goes back, which '
        'is ${owed.percentage}% of what was paid.';
  }
}
