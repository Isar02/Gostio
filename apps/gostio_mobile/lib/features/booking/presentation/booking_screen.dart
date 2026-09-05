import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../payment/data/card_sheet.dart';
import '../../payment/data/payment_repository.dart';
import '../../payment/presentation/pay_bar.dart';
import '../../payment/presentation/payment_notifier.dart';
import 'hold_countdown.dart';
import 'price_table.dart';

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

  // A booking against a term carries the id of that term rather than the hour
  // it begins, so the screen that chose it hands the term over instead of the
  // screen reading it again.
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
    final TextTheme text = Theme.of(context).textTheme;
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
            Text(booking.listingTitle, style: text.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            for (final (String label, String value) in _facts(booking))
              _Fact(label: label, value: value),
            const SizedBox(height: AppSpacing.lg),
            // A paid booking holds nothing: the sentence about the deadline is
            // replaced by the one that made it moot.
            if (payment.isPaid)
              const AppNotice('This booking is paid for.', tone: Tone.positive)
            else
              HoldCountdown(booking.expiresAt, onRanOut: payment.holdRanOut),
            const SizedBox(height: AppSpacing.xl),
            PriceTable(lines: _lines(booking), total: booking.totalPrice),
          ],
        ),
      ),
      bottomNavigationBar: const PayBar(),
    );
  }

  List<(String, String)> _facts(Reservation booking) {
    if (booking.stay case (final DateTime arrival, final DateTime departure)) {
      return <(String, String)>[
        ('Check in', AppDates.day(arrival)),
        ('Check out', AppDates.day(departure)),
        ('Guests', AppNumbers.counted(booking.guestCount, 'guest')),
      ];
    }

    return <(String, String)>[
      if (term case final ExperienceSlot term) ...<(String, String)>[
        ('Starts', AppDates.dateTime(term.startTime)),
        ('Lasts', AppDurations.inWords(term.durationMinutes)),
      ],
      ('Guests', AppNumbers.counted(booking.guestCount, 'guest')),
    ];
  }

  List<(String, double)> _lines(Reservation booking) {
    if (booking.stay case (final DateTime arrival, final DateTime departure)) {
      return <(String, double)>[
        (
          AppNumbers.counted(
            CalendarDays.daysBetween(arrival, departure),
            'night',
          ),
          booking.accommodationTotal ?? booking.totalPrice,
        ),
        if (booking.cleaningFee case final double fee when fee > 0)
          ('Cleaning fee', fee),
      ];
    }

    return <(String, double)>[
      (AppNumbers.counted(booking.guestCount, 'guest'), booking.totalPrice),
    ];
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(value, style: text.bodyMedium),
        ],
      ),
    );
  }
}
