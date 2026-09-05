import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../payment/data/card_sheet.dart';
import '../../payment/data/payment_repository.dart';
import '../../payment/presentation/pay_bar.dart';
import '../../payment/presentation/payment_notifier.dart';
import 'booking_summary.dart';
import 'hold_countdown.dart';

// The booking that was just made: what it is for, who is coming, what it costs
// and how long it keeps its place. Nothing has been paid for at this point, and
// the hold above the figures is what says so.
class BookingScreen extends StatelessWidget {
  const BookingScreen(this.booking, {this.term, super.key});

  // The screen that made the booking is replaced rather than left underneath
  // it. Back from a booking that exists should not reach the form that made
  // it, where pressing Book again would make a second one.
  static Future<void> openReplacing(
    NavigatorState navigator,
    Reservation booking, {
    ExperienceSlot? term,
  }) => navigator.pushReplacement(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => BookingScreen(booking, term: term),
    ),
  );

  final Reservation booking;

  // A booking against a term says when that term begins but not how long it
  // runs, so the screen that chose the term hands it over rather than reading
  // it a second time.
  final ExperienceSlot? term;

  @override
  Widget build(BuildContext context) {
    // The booking this screen draws is the notifier's from here on: paying
    // reads it back, and what comes back is what the reader is shown.
    return ChangeNotifierProvider<PaymentNotifier>(
      create: (BuildContext context) => PaymentNotifier(
        context.read<PaymentRepository>(),
        context.read<CardSheet>(),
        booking,
      ),
      child: _Booking(term: term),
    );
  }
}

class _Booking extends StatelessWidget {
  const _Booking({this.term});

  final ExperienceSlot? term;

  @override
  Widget build(BuildContext context) {
    final PaymentNotifier payment = context.watch<PaymentNotifier>();
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
            BookingSummary(
              booking,
              term: term,
              // A paid booking holds nothing: the sentence about the deadline
              // is replaced by the one that made it moot.
              standing: payment.isPaid
                  ? const AppNotice(
                      'This booking is paid for.',
                      tone: Tone.positive,
                    )
                  : HoldCountdown(
                      booking.expiresAt,
                      onRanOut: payment.holdRanOut,
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const PayBar(),
    );
  }
}
