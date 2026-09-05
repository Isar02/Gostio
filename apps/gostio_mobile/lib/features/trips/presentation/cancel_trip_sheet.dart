import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/forms/form_fields.dart';
import '../../../core/forms/form_validation.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/app_sheet.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/discard_guard.dart';
import 'cancel_trip_notifier.dart';

// Calling a booking off cannot be undone, so this sheet is the confirmation
// itself: what happens, what comes back, and the reason the server asks for.
// What comes back is read before the button rather than reported after it.
abstract final class CancelTripSheet {
  static Future<void> show(BuildContext context, Reservation booking) {
    final CancelTripNotifier cancelling = context.read<CancelTripNotifier>()
      ..prepare();

    return AppSheet.show<void>(
      context,
      title: 'Cancel this booking?',
      isScrollable: false,
      // The notifier belongs to the trip route and outlives this sheet. The
      // sheet borrows it so a write that finishes after this closes still
      // reaches the booking owner.
      builder: (BuildContext context) =>
          ChangeNotifierProvider<CancelTripNotifier>.value(
            value: cancelling,
            child: _CancelForm(booking),
          ),
    );
  }
}

class _CancelForm extends StatefulWidget {
  const _CancelForm(this.booking);

  final Reservation booking;

  @override
  State<_CancelForm> createState() => _CancelFormState();
}

class _CancelFormState extends State<_CancelForm>
    with FormValidation<_CancelForm> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final FormFields _fields = FormFields(<String>['reason']);
  final TextEditingController _reason = TextEditingController();

  @override
  void initState() {
    super.initState();

    _reason.addListener(_typingChanged);
  }

  @override
  void dispose() {
    _reason
      ..removeListener(_typingChanged)
      ..dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CancelTripNotifier cancelling = context.watch<CancelTripNotifier>();
    final TextTheme text = Theme.of(context).textTheme;

    return DiscardGuard(
      hasInput: _reason.text.isNotEmpty && !cancelling.isBusy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    _whatHappens,
                    style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Owed(
                    quote: cancelling.quote,
                    isReading: cancelling.isReadingQuote,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Form(
                    key: _form,
                    autovalidateMode: validation,
                    child: TextFormField(
                      key: _fields['reason'],
                      controller: _reason,
                      enabled: !cancelling.isBusy,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: 'Reason',
                        alignLabelWithHint: true,
                        helperText: 'The host is told why.',
                        errorText: cancelling.messageFor('reason'),
                      ),
                      validator: Validators.cancellationReason,
                      onChanged: (_) => cancelling.clearFailureFor('reason'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (cancelling.refusal case final String refusal)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: AppNotice(refusal),
            ),
          BottomActionBar(
            secondary: TextButton(
              onPressed: cancelling.isBusy
                  ? null
                  : () => Navigator.of(context).maybePop(),
              child: const Text('Keep it'),
            ),
            // What comes back is part of the decision, so the decision waits
            // for it.
            action: FilledButton(
              style: _destructive,
              onPressed: cancelling.isBusy || cancelling.isReadingQuote
                  ? null
                  : _submit,
              child: Text(
                cancelling.isBusy ? 'Cancelling' : 'Cancel the booking',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // A stay gives its dates back; a term gives the places it holds back to the
  // term.
  String get _whatHappens {
    final Reservation booking = widget.booking;

    return booking.isTerm
        ? 'The places this holds on ${booking.listingTitle} go back to the '
              'term, and the host is told. This cannot be undone.'
        : '${booking.listingTitle} goes back on offer for these dates, and the '
              'host is told. This cannot be undone.';
  }

  void _typingChanged() => setState(() {});

  Future<void> _submit() async {
    if (!validate(_form, _fields)) {
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final ModalRoute<Object?>? sheet = ModalRoute.of(context);
    final CancelTripNotifier cancelling = context.read<CancelTripNotifier>();
    final bool cancelled = await cancelling.cancel(_reason.text.trim());

    if (!cancelled) {
      final ApiException? refused = cancelling.failure;
      if ((sheet?.isCurrent ?? false) && refused != null) {
        _fields.revealFault(refused);
      }

      return;
    }

    // The notifier has already handed the returned row to its owner. This
    // closes only the sheet, and only where the reader has not already left.
    if (sheet?.isCurrent ?? false) {
      navigator.pop();
    }
  }

  static final ButtonStyle _destructive = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.pressed)
          ? AppColors.dangerDeep
          : AppColors.danger,
    ),
  );
}

// What the policy sends back, read while calling the booking off is still a
// choice. A booking nobody paid for owes nothing back whatever the policy
// works out, and is told in those words rather than as a figure of zero.
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

  String _amount(RefundQuote owed) {
    if (!owed.isPaid) {
      return 'Nothing was charged for this booking, so nothing goes back.';
    }

    return '${AppNumbers.moneyIn(owed.amount, owed.currency)} of '
        '${AppNumbers.moneyIn(owed.charged, owed.currency)} goes back, which '
        'is ${owed.percentage}% of what was paid.';
  }
}
