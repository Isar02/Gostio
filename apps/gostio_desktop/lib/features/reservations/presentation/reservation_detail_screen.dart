import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/account_avatar.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/status_chip.dart';
import '../../experiences/data/experience_slots_repository.dart';
import '../../listings/presentation/booking_colours.dart';
import '../data/reservations_repository.dart';
import 'cancel_reservation_dialog.dart';
import 'reservation_detail_notifier.dart';
import 'settlement_tone.dart';
import 'side_read.dart';

class ReservationDetailScreen extends StatelessWidget {
  const ReservationDetailScreen({required this.reservationId, super.key});

  final int reservationId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReservationDetailNotifier>(
      create: (BuildContext context) {
        final ReservationDetailNotifier notifier = ReservationDetailNotifier(
          context.read<ReservationsRepository>(),
          context.read<ExperienceSlotsRepository>(),
          reservationId: reservationId,
        );
        unawaited(notifier.load());

        return notifier;
      },
      child: const _Detail(),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail();

  @override
  Widget build(BuildContext context) {
    final ReservationDetailNotifier notifier = context
        .watch<ReservationDetailNotifier>();
    final Reservation? booking = notifier.reservation;

    // Only a page with nothing on it is emptied; a booking already drawn
    // stays drawn while the read that follows a move runs.
    if (booking == null) {
      if (notifier.isLoading) {
        return const LoadingState(message: 'Reading the booking');
      }

      return ErrorState(
        message: notifier.failureMessage ?? 'This booking could not be read.',
        onRetry: notifier.load,
        traceId: notifier.failureTraceId,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(notifier: notifier, booking: booking),
        _Progress(isRunning: notifier.isLoading),
        Expanded(
          child: _Panels(notifier: notifier, booking: booking),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.isRunning});

  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizes.stroke,
      child: isRunning
          ? const LinearProgressIndicator(minHeight: AppSizes.stroke)
          : null,
    );
  }
}

class _Panels extends StatelessWidget {
  const _Panels({required this.notifier, required this.booking});

  final ReservationDetailNotifier notifier;
  final Reservation booking;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (notifier.writeFailureMessage
              case final String refusal) ...<Widget>[
            AppNotice(refusal),
            const SizedBox(height: AppSpacing.lg),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Booked(booking: booking, term: notifier.term),
                    const SizedBox(height: AppSpacing.lg),
                    _Guest(booking: booking),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _Money(booking: booking),
                    const SizedBox(height: AppSpacing.lg),
                    _Payment(payment: notifier.payment),
                    const SizedBox(height: AppSpacing.lg),
                    _Refund(refund: notifier.refund),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.notifier, required this.booking});

  final ReservationDetailNotifier notifier;
  final Reservation booking;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          // A write in flight has not said what it did yet, so leaving now
          // would hand the list back a row that is about to be wrong.
          IconButton(
            onPressed: notifier.isWriting
                ? null
                : () =>
                      Navigator.of(context)
                          .pop(notifier.hasMoved ? booking : null),
            icon: const Icon(Icons.arrow_back),
            tooltip: notifier.isWriting
                ? 'The move being written has to land first.'
                : 'Back to the list',
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  booking.guestName,
                  style: text.titleLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${booking.listingTitle} · booked '
                  '${AppDates.date(booking.createdAt)}',
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          StatusChip(
            booking.status,
            tone: BookingColours.tone(booking.standing),
          ),
          const SizedBox(width: AppSpacing.lg),
          _Moves(notifier: notifier, booking: booking),
        ],
      ),
    );
  }
}

class _Moves extends StatelessWidget {
  const _Moves({required this.notifier, required this.booking});

  final ReservationDetailNotifier notifier;
  final Reservation booking;

  @override
  Widget build(BuildContext context) {
    final ReservationStatus? standing = booking.standing;
    final bool isBusy = notifier.isBusy;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Tooltip(
          message: _confirmMeans(standing),
          child: FilledButton(
            onPressed: (standing?.canBeConfirmed ?? false) && !isBusy
                ? () => _confirm(context)
                : null,
            child: Text(notifier.isWriting ? 'Writing' : 'Confirm'),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Tooltip(
          message: _cancelMeans(standing),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: (standing?.canBeCancelled ?? false) && !isBusy
                ? () => _cancel(context)
                : null,
            child: const Text('Cancel booking'),
          ),
        ),
      ],
    );
  }

  static String _confirmMeans(ReservationStatus? standing) =>
      switch (standing) {
        ReservationStatus.pending =>
          'Hold the place for this guest and tell them so.',
        ReservationStatus.confirmed => 'This booking is already confirmed.',
        ReservationStatus.cancelled =>
          'A cancelled booking cannot be confirmed.',
        ReservationStatus.completed =>
          'A booking that is over cannot be confirmed.',
        null =>
          'This booking is in a standing this client does not move it out of.',
      };

  static String _cancelMeans(ReservationStatus? standing) => switch (standing) {
    ReservationStatus.pending ||
    ReservationStatus.confirmed => 'End this booking and give the place back.',
    ReservationStatus.cancelled => 'This booking is already cancelled.',
    ReservationStatus.completed =>
      'A booking that is over cannot be cancelled.',
    null =>
      'This booking is in a standing this client does not move it out of.',
  };

  Future<void> _confirm(BuildContext context) async {
    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Confirm this booking?',
      message:
          '${booking.listingTitle} is held for ${booking.guestName} and they '
          'are told. The only way out of a confirmed booking is cancelling it.',
      confirmLabel: 'Confirm booking',
    );

    if (agreed) {
      await notifier.confirm();
    }
  }

  Future<void> _cancel(BuildContext context) => showDialog<void>(
    context: context,
    builder: (BuildContext context) => CancelReservationDialog(
      reservation: booking,
      readQuote: notifier.refundQuote,
      cancel: notifier.cancel,
    ),
  );
}

class _Booked extends StatelessWidget {
  const _Booked({required this.booking, required this.term});

  final Reservation booking;
  final SideRead<ExperienceSlot> term;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: booking.isTerm ? 'The term' : 'The stay',
      children: <Widget>[
        _Fact('Listing', booking.listingTitle),
        if (booking.stay case (final DateTime arrival, final DateTime leaving))
          ..._nights(arrival, leaving)
        else
          ..._runs(),
        _Fact('Guests', '${booking.guestCount}'),
      ],
    );
  }

  // A stay ends on a day it does not cover, so the nights are the difference.
  List<Widget> _nights(DateTime arrival, DateTime leaving) => <Widget>[
    _Fact('Check-in', AppDates.day(arrival)),
    _Fact('Check-out', AppDates.day(leaving)),
    _Fact('Nights', '${CalendarDays.daysBetween(arrival, leaving)}'),
  ];

  List<Widget> _runs() {
    if (term.value case final ExperienceSlot slot) {
      return <Widget>[
        _Fact('Starts', AppDates.dateTime(slot.startTime)),
        _Fact('Ends', AppDates.time(slot.endTime)),
        _Fact('Runs for', AppDurations.inWords(slot.durationMinutes)),
      ];
    }

    return <Widget>[
      _Fact(
        'Starts',
        term.failure == null
            ? 'This booking names no term.'
            : 'The term could not be read.',
      ),
    ];
  }
}

class _Guest extends StatelessWidget {
  const _Guest({required this.booking});

  final Reservation booking;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'The guest',
      children: <Widget>[
        Row(
          children: <Widget>[
            AccountAvatar(userId: booking.userId, name: booking.guestName),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                booking.guestName,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _Fact('Booked', AppDates.dateTime(booking.createdAt)),
        if (booking.standing == ReservationStatus.pending)
          _Fact('Held until', AppDates.dateTime(booking.expiresAt)),
      ],
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.booking});

  final Reservation booking;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'What it comes to',
      children: <Widget>[
        if (booking.accommodationTotal case final double nights)
          _Fact('Nights', AppNumbers.money(nights)),
        if (booking.cleaningFee case final double cleaning)
          _Fact('Cleaning', AppNumbers.money(cleaning)),
        if (booking.pricePerPerson case final double head)
          _Fact('A place', AppNumbers.money(head)),
        _Fact('Total', AppNumbers.money(booking.totalPrice)),
        _Fact('Settled', booking.isPaid ? 'Paid' : 'Not paid'),
      ],
    );
  }
}

class _Payment extends StatelessWidget {
  const _Payment({required this.payment});

  final SideRead<ReservationPayment> payment;

  @override
  Widget build(BuildContext context) {
    if (payment.failure case final ApiException failure) {
      return _Panel(
        title: 'The payment',
        children: <Widget>[_Unread('The charge could not be read.', failure)],
      );
    }

    if (payment.value case final ReservationPayment charge) {
      return _Panel(
        title: 'The payment',
        children: <Widget>[
          _Settlement(charge.status),
          const SizedBox(height: AppSpacing.md),
          _Fact('Amount', AppNumbers.moneyIn(charge.amount, charge.currency)),
          _Fact('Opened', AppDates.dateTime(charge.createdAt)),
          if (charge.processedAt case final DateTime settled)
            _Fact('Settled', AppDates.dateTime(settled)),
          if (charge.failureReason case final String refusal)
            _Fact('Refused', refusal),
        ],
      );
    }

    return const _Panel(
      title: 'The payment',
      children: <Widget>[_Nothing('Nothing has been charged for this yet.')],
    );
  }
}

class _Refund extends StatelessWidget {
  const _Refund({required this.refund});

  final SideRead<ReservationRefund> refund;

  @override
  Widget build(BuildContext context) {
    if (refund.failure case final ApiException failure) {
      return _Panel(
        title: 'The refund',
        children: <Widget>[_Unread('The refund could not be read.', failure)],
      );
    }

    if (refund.value case final ReservationRefund back) {
      return _Panel(
        title: 'The refund',
        children: <Widget>[
          _Settlement(back.status),
          const SizedBox(height: AppSpacing.md),
          _Fact('Amount', AppNumbers.moneyIn(back.amount, back.currency)),
          // The rule that set the amount, not why the booking was called off.
          _Fact('Under', back.reason),
          _Fact('Opened', AppDates.dateTime(back.createdAt)),
          if (back.processedAt case final DateTime settled)
            _Fact('Settled', AppDates.dateTime(settled)),
          if (back.failureReason case final String refusal)
            _Fact('Refused', refusal),
        ],
      );
    }

    return const _Panel(
      title: 'The refund',
      children: <Widget>[_Nothing('Nothing is owed back on this booking.')],
    );
  }
}

class _Settlement extends StatelessWidget {
  const _Settlement(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: StatusChip(status, tone: SettlementTone.of(status)),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.large,
        border: Border.all(color: AppColors.border, width: AppSizes.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge
                ?.copyWith(color: AppColors.inkMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _factLabel,
            child: Text(
              label,
              style: text.labelSmall?.copyWith(color: AppColors.inkFaint),
            ),
          ),
          Expanded(child: Text(value, style: text.bodyMedium)),
        ],
      ),
    );
  }
}

class _Nothing extends StatelessWidget {
  const _Nothing(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: AppColors.inkFaint),
    );
  }
}

class _Unread extends StatelessWidget {
  const _Unread(this.what, this.failure);

  final String what;
  final ApiException failure;

  @override
  Widget build(BuildContext context) {
    return AppNotice('$what ${failure.message}', tone: Tone.attention);
  }
}

// The longest label a panel carries, so both sides line up as one column.
const double _factLabel = 96;
