import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/discard_guard.dart';
import '../../../core/widgets/paged_list.dart';
import '../../../core/widgets/quantity_stepper.dart';
import '../../../core/widgets/section_header.dart';
import '../data/booking_repository.dart';
import 'booking_screen.dart';
import 'term_booking_notifier.dart';
import 'term_card.dart';
import 'terms_notifier.dart';

// A term being booked: the ones this experience still has open, the places
// left on each, and the party coming on the one that was chosen.
//
// A term the reader already holds a place on is drawn as theirs rather than
// offered, because a guest holds one place on a term and no more. That is said
// here rather than left to the refusal the server would answer with.
class BookTermScreen extends StatelessWidget {
  const BookTermScreen(this.experience, {super.key});

  static Future<void> open(BuildContext context, Experience experience) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => BookTermScreen(experience),
        ),
      );

  final Experience experience;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        ChangeNotifierProvider<TermsNotifier>(
          create: (BuildContext context) =>
              TermsNotifier(context.read<BookingRepository>(), experience.id),
        ),
        ChangeNotifierProvider<TermBookingNotifier>(
          create: (BuildContext context) => TermBookingNotifier(
            context.read<BookingRepository>(),
            experience,
          ),
        ),
      ],
      child: _BookTerm(experience),
    );
  }
}

class _BookTerm extends StatelessWidget {
  const _BookTerm(this.experience);

  final Experience experience;

  @override
  Widget build(BuildContext context) {
    return Consumer2<TermsNotifier, TermBookingNotifier>(
      builder:
          (
            BuildContext context,
            TermsNotifier terms,
            TermBookingNotifier booking,
            Widget? _,
          ) => DiscardGuard(
            hasInput: booking.hasInput,
            title: 'Leave this booking?',
            message: 'What you chose here will not be kept.',
            child: Scaffold(
              appBar: AppBar(
                title: Text(
                  experience.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              body: SafeArea(
                child: Column(
                  children: <Widget>[
                    Expanded(child: _terms(terms, booking)),
                    if (booking.chosen case final ExperienceSlot chosen)
                      _Party(booking: booking, chosen: chosen),
                  ],
                ),
              ),
              bottomNavigationBar: BottomActionBar(
                label: booking.chosen == null
                    ? 'Choose a term'
                    : AppNumbers.money(booking.total),
                detail: booking.chosen == null ? null : _party(booking),
                action: FilledButton(
                  onPressed: booking.isBookable
                      ? () => _book(context, booking)
                      : null,
                  child: Text(booking.isBusy ? 'Booking' : 'Book'),
                ),
              ),
            ),
          ),
    );
  }

  Widget _terms(TermsNotifier terms, TermBookingNotifier booking) {
    return PagedList<ExperienceSlot>(
      items: terms.items,
      totalCount: terms.totalCount,
      isLoading: terms.isLoading,
      isAppending: terms.isAppending,
      failureMessage: terms.failureMessage,
      failureTraceId: terms.failureTraceId,
      onRetry: terms.retry,
      onMore: terms.more,
      noun: 'terms',
      emptyTitle: 'No terms open',
      emptyMessage: 'This experience has nothing left to book.',
      header: SectionHeader(
        'Open terms',
        subtitle:
            '${AppNumbers.money(experience.pricePerPerson)} a person. '
            'Choose the one you want to come on.',
      ),
      itemBuilder: (BuildContext context, ExperienceSlot term) {
        final bool isHeld = terms.alreadyHeld.contains(term.id);

        return TermCard(
          term: term,
          isChosen: term.id == booking.chosen?.id,
          isHeld: isHeld,
          onChosen: isHeld || term.remainingCapacity < 1
              ? null
              : () => booking.choose(term),
        );
      },
    );
  }

  String _party(TermBookingNotifier booking) =>
      '${AppNumbers.counted(booking.guestCount, 'guest')} at '
      '${AppNumbers.money(experience.pricePerPerson)}';

  // Asked of the form's own route rather than of the navigator it was pushed
  // into, which outlives it: see the note on the stay screen's booking.
  Future<void> _book(BuildContext context, TermBookingNotifier booking) async {
    final NavigatorState navigator = Navigator.of(context);
    final ModalRoute<Object?>? form = ModalRoute.of(context);
    final ExperienceSlot? term = booking.chosen;
    final Reservation? made = await booking.book();

    if (made != null && (form?.isCurrent ?? false)) {
      unawaited(BookingScreen.openReplacing(navigator, made, term: term));
    }
  }
}

// The party on the term that was chosen, held over the list rather than
// scrolled to: the figure in the bar under it is priced from this.
class _Party extends StatelessWidget {
  const _Party({required this.booking, required this.chosen});

  final TermBookingNotifier booking;
  final ExperienceSlot chosen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: AppSizes.hairline),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: <Widget>[
          QuantityStepper(
            label: 'Guests',
            detail:
                '${AppDates.dateTime(chosen.startTime)} · '
                '${AppNumbers.counted(chosen.remainingCapacity, 'place')} left',
            value: booking.guestCount,
            minimum: 1,
            maximum: booking.maximumGuests,
            onChanged: booking.setGuestCount,
          ),
          if (booking.refusal case final String refusal) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            AppNotice(refusal),
          ],
        ],
      ),
    );
  }
}
