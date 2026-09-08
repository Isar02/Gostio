import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/status_chip.dart';
import '../../booking/presentation/booking_summary.dart';
import '../../booking/presentation/hold_countdown.dart';
import '../../messages/data/thread_subject.dart';
import '../../messages/presentation/open_thread_button.dart';
import '../../payment/data/card_sheet.dart';
import '../../payment/data/payment_repository.dart';
import '../../payment/presentation/pay_bar.dart';
import '../../payment/presentation/payment_notifier.dart';
import '../data/trips_repository.dart';
import 'cancel_trip_notifier.dart';
import 'cancel_trip_sheet.dart';
import 'standing_tone.dart';

// One booking the reader has come back to: where it stands, what it is for,
// what it comes to, and the two things that can still be done to it — settling
// it, and calling it off.
//
// It draws the row the list handed it and never sets a standing of its own.
// Both writes answer with the booking as the server then holds it, and that
// row is what is drawn from there on and what the list behind is told.
class TripScreen extends StatelessWidget {
  const TripScreen(
    this.booking, {
    this.onChanged,
    this.completedContent,
    super.key,
  });

  static Future<void> open(
    BuildContext context,
    Reservation booking, {
    ValueChanged<Reservation>? onChanged,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          TripScreen(booking, onChanged: onChanged),
    ),
  );

  final Reservation booking;

  // What the server answered here, for the list this was opened from: it is
  // showing the same booking, and it read it before either write happened.
  final ValueChanged<Reservation>? onChanged;

  // Content another module composes under a finished booking. Trips owns the
  // booking and its standing; the application owns which feature is drawn
  // beside it.
  final Widget? completedContent;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<PaymentNotifier>(
          create: (BuildContext context) => PaymentNotifier(
            context.read<PaymentRepository>(),
            context.read<CardSheet>(),
            booking,
            onBooking: onChanged,
          ),
        ),
        ChangeNotifierProvider<CancelTripNotifier>(
          create: (BuildContext context) => CancelTripNotifier(
            context.read<TripsRepository>(),
            booking.id,
            context.read<PaymentNotifier>().bookingChanged,
          ),
        ),
      ],
      child: _Trip(completedContent: completedContent),
    );
  }
}

class _Trip extends StatelessWidget {
  const _Trip({this.completedContent});

  final Widget? completedContent;

  @override
  Widget build(BuildContext context) {
    final PaymentNotifier payment = context.watch<PaymentNotifier>();
    final CancelTripNotifier cancelling = context.watch<CancelTripNotifier>();
    final Reservation booking = payment.booking;

    return Scaffold(
      appBar: AppBar(title: const Text('Your booking')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(
                booking.status,
                tone: StandingTone.of(booking.standing),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            BookingSummary(booking, standing: _standing(payment)),
            const SizedBox(height: AppSpacing.xl),
            // The thread about this booking, which is the same one the host
            // reaches from their side and the one the server answers again
            // rather than opening a second.
            OpenThreadButton(
              subject: AboutBooking(booking.id),
              label: 'Message the host',
            ),
            // A booking is reviewed once it is behind the guest, which is the
            // server's rule and is mirrored rather than reproduced: what it
            // decides is still the server's, and a section that would only
            // earn a refusal is not put in front of a reader.
            if (booking.standing == ReservationStatus.completed &&
                completedContent != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xxl),
              completedContent!,
            ],
          ],
        ),
      ),
      // A booking the server would refuse to move is not offered the move, and
      // the move it is offered stands with the payment rather than up the page.
      bottomNavigationBar: cancelling.isBusy
          ? const SizedBox.shrink()
          : PayBar(
              cancel:
                  (booking.standing?.canBeCancelled ?? false) &&
                      payment.stage == PaymentStage.idle
                  ? OutlinedButton(
                      style: _destructive,
                      onPressed: () => unawaited(_cancel(context, payment)),
                      child: const Text('Cancel this booking'),
                    )
                  : null,
            ),
    );
  }

  // Where the booking stands in one sentence, which is a different sentence
  // from the word in the chip: the chip says what it is, and this says what
  // that means for the reader.
  Widget? _standing(PaymentNotifier payment) {
    final Reservation booking = payment.booking;

    if (booking.standing == ReservationStatus.cancelled) {
      return AppNotice(
        booking.isPaid
            ? 'This booking was called off. What was paid for it goes back '
                  'under the cancellation policy.'
            : 'This booking was called off.',
        tone: Tone.negative,
      );
    }

    if (payment.isPaid) {
      return const AppNotice('This booking is paid for.', tone: Tone.positive);
    }

    // Only a pending booking is under a hold. A confirmed one keeps its place
    // whatever the deadline it was made under said.
    return booking.standing == ReservationStatus.pending
        ? HoldCountdown(booking.expiresAt, onRanOut: payment.holdRanOut)
        : null;
  }

  // The cancellation notifier lives beside the booking owner and lends itself
  // to the sheet, so its in-flight state and returned row survive that surface.
  Future<void> _cancel(BuildContext context, PaymentNotifier payment) =>
      CancelTripSheet.show(context, payment.booking);

  static final ButtonStyle _destructive = ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith<Color>(
      (Set<WidgetState> states) => states.contains(WidgetState.disabled)
          ? AppColors.inkFaint
          : AppColors.danger,
    ),
    side: WidgetStateProperty.resolveWith<BorderSide>(
      (Set<WidgetState> states) => BorderSide(
        color: states.contains(WidgetState.disabled)
            ? AppColors.border
            : AppColors.danger,
      ),
    ),
  );
}
