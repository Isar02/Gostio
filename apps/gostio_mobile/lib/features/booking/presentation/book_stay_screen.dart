import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../core/calendar/date_range.dart';
import '../../../core/calendar/stay_calendar_notifier.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stay_month_calendar.dart';
import '../../listing/data/listing_repository.dart';
import '../data/booking_repository.dart';
import '../data/stay_quote.dart';
import 'booking_screen.dart';
import 'price_table.dart';
import 'stay_booking_notifier.dart';

// A stay being booked: the nights taken off the listing's own calendar, the
// party coming, and what the two add up to beside the button that sends them.
//
// The calendar is read a month at a time. A range can only be closed over
// nights that have landed, so every night the total is made of is one the
// server priced.
class BookStayScreen extends StatelessWidget {
  const BookStayScreen(this.stay, {super.key});

  static Future<void> open(BuildContext context, Accommodation stay) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => BookStayScreen(stay),
        ),
      );

  final Accommodation stay;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<StayCalendarNotifier>(
          create: (BuildContext context) {
            final ListingRepository listings = context
                .read<ListingRepository>();

            return StayCalendarNotifier(
              (DateTime from, DateTime to) =>
                  listings.calendar(stay.id, from: from, to: to),
            );
          },
        ),
        ChangeNotifierProvider<StayBookingNotifier>(
          create: (BuildContext context) =>
              StayBookingNotifier(context.read<BookingRepository>(), stay),
        ),
      ],
      child: _BookStay(stay),
    );
  }
}

class _BookStay extends StatelessWidget {
  const _BookStay(this.stay);

  final Accommodation stay;

  @override
  Widget build(BuildContext context) {
    return Consumer2<StayCalendarNotifier, StayBookingNotifier>(
      builder:
          (
            BuildContext context,
            StayCalendarNotifier calendar,
            StayBookingNotifier booking,
            Widget? _,
          ) {
            final StayQuote? quote = _quote(calendar, booking);

            return DiscardGuard(
              hasInput: booking.hasInput,
              title: 'Leave this booking?',
              message: 'What you chose here will not be kept.',
              child: Scaffold(
                appBar: AppBar(
                  title: Text(
                    stay.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                body: SafeArea(child: _body(calendar, booking, quote)),
                // The refusal is held beside the button that earned it rather
                // than at the end of the sections, where the reader who
                // pressed Book would have to go looking for it.
                bottomNavigationBar: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (booking.refusal case final String refusal)
                      _Refusal(refusal),
                    BottomActionBar(
                      label: quote == null
                          ? 'Choose your dates'
                          : AppNumbers.money(quote.total),
                      detail: quote == null ? null : _party(quote, booking),
                      action: FilledButton(
                        onPressed: booking.isBookable
                            ? () => _book(context, booking)
                            : null,
                        child: Text(booking.isBusy ? 'Booking' : 'Book'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
    );
  }

  Widget _body(
    StayCalendarNotifier calendar,
    StayBookingNotifier booking,
    StayQuote? quote,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      children: <Widget>[
        _Block(
          child: SectionHeader(
            'Your dates',
            subtitle:
                'Figures are ${AppNumbers.currency} per night. Tap the night '
                'you arrive, then the day you leave.',
          ),
        ),
        StayMonthCalendar(
          calendar: calendar,
          from: booking.choice.from,
          to: booking.choice.to,
          isTakeable: (DateTime day) =>
              booking.choice.mayTake(day, isNight: calendar.isBookable),
          onChosen: (DateTime day) =>
              booking.take(day, isNight: calendar.isBookable),
        ),
        _Block(child: _Chosen(booking)),
        _Block(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              QuantityStepper(
                label: 'Guests',
                detail: 'This place sleeps ${stay.maxGuests}.',
                value: booking.guestCount,
                minimum: 1,
                maximum: booking.maximumGuests,
                onChanged: booking.setGuestCount,
              ),
            ],
          ),
        ),
        if (quote case final StayQuote quote)
          _Block(
            child: Column(
              children: <Widget>[
                const Divider(),
                const SizedBox(height: AppSpacing.lg),
                PriceTable(lines: _lines(quote), total: quote.total),
              ],
            ),
          ),
      ],
    );
  }

  StayQuote? _quote(
    StayCalendarNotifier calendar,
    StayBookingNotifier booking,
  ) {
    final DateRange? dates = booking.dates;

    return dates == null
        ? null
        : StayQuote.of(
            dates,
            priceOf: (DateTime night) => calendar.nightOf(night)?.price,
            cleaningFee: stay.cleaningFee,
          );
  }

  List<(String, double)> _lines(StayQuote quote) => <(String, double)>[
    (AppNumbers.counted(quote.nights, 'night'), quote.nightsTotal),
    if (quote.cleaningFee > 0) ('Cleaning fee', quote.cleaningFee),
  ];

  String _party(StayQuote quote, StayBookingNotifier booking) =>
      '${AppNumbers.counted(quote.nights, 'night')} · '
      '${AppNumbers.counted(booking.guestCount, 'guest')}';

  // The form may be left while the booking is in flight, and the navigator it
  // was pushed into outlives it: a late answer measured against that navigator
  // would land the booking's screen on top of whatever replaced this form. The
  // form's own route is what is asked instead. The booking was still made and
  // is the account's; it is read from the trips list rather than pushed at a
  // reader who has gone somewhere else.
  Future<void> _book(BuildContext context, StayBookingNotifier booking) async {
    final NavigatorState navigator = Navigator.of(context);
    final ModalRoute<Object?>? form = ModalRoute.of(context);
    final Reservation? made = await booking.book();

    if (made != null && (form?.isCurrent ?? false)) {
      unawaited(BookingScreen.openReplacing(navigator, made));
    }
  }
}

// The dates as they stand, and the way back out of them. It says nothing until
// a first night is held, because the header above already says what the first
// tap is for.
class _Chosen extends StatelessWidget {
  const _Chosen(this.booking);

  final StayBookingNotifier booking;

  @override
  Widget build(BuildContext context) {
    final DateTime? from = booking.choice.from;
    if (from == null) {
      return const SizedBox.shrink();
    }

    final DateRange? dates = booking.dates;

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            dates == null
                ? '${AppDates.day(from)} — now choose the day you leave'
                : '${AppDates.day(dates.from)} to ${AppDates.day(dates.to)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        TextButton(onPressed: booking.clearDates, child: const Text('Clear')),
      ],
    );
  }
}

class _Refusal extends StatelessWidget {
  const _Refusal(this.message);

  final String message;

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
        child: AppNotice(message),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
        0,
      ),
      child: child,
    );
  }
}
