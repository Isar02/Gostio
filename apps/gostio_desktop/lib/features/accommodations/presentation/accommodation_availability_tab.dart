import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/formatting/app_dates.dart';
import '../../../core/formatting/app_numbers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/screen_states.dart';
import '../../reservations/data/reservations_repository.dart';
import '../data/accommodation_availability.dart';
import '../data/accommodation_availability_repository.dart';
import 'accommodation_availability_notifier.dart';
import 'availability_calendar.dart';
import 'availability_entry_dialog.dart';
import 'availability_month.dart';
import 'availability_words.dart';

class AccommodationAvailabilityTab extends StatelessWidget {
  const AccommodationAvailabilityTab({
    required this.accommodationId,
    required this.nightlyPrice,
    super.key,
  });

  final int accommodationId;
  final double nightlyPrice;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AccommodationAvailabilityNotifier>(
      create: (BuildContext context) {
        final AccommodationAvailabilityNotifier calendar =
            AccommodationAvailabilityNotifier(
              context.read<AccommodationAvailabilityRepository>(),
              context.read<ReservationsRepository>(),
              accommodationId: accommodationId,
            );
        unawaited(calendar.load());

        return calendar;
      },
      child: _Availability(nightlyPrice: nightlyPrice),
    );
  }
}

class _Availability extends StatelessWidget {
  const _Availability({required this.nightlyPrice});

  final double nightlyPrice;

  @override
  Widget build(BuildContext context) {
    final AccommodationAvailabilityNotifier calendar = context
        .watch<AccommodationAvailabilityNotifier>();

    if (calendar.shown case final AvailabilityMonth shown) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _MonthBar(calendar: calendar, shown: shown),
            const SizedBox(height: AppSpacing.md),
            _Chosen(calendar: calendar, nightlyPrice: nightlyPrice),
            if (calendar.failureMessage case final String message) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              AppNotice(message),
            ],
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: AvailabilityCalendar(
                shown: shown,
                highlight: calendar.highlight,
                isHighlightRefused: calendar.isSelectionRefused,
                onChoose: calendar.chooseDay,
                onReach: calendar.reachTo,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Legend(nightlyPrice: nightlyPrice),
          ],
        ),
      );
    }

    if (calendar.failureMessage case final String message) {
      return ErrorState(
        message: message,
        onRetry: calendar.load,
        traceId: calendar.failureTraceId,
      );
    }

    return const LoadingState(message: 'Reading the calendar');
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.calendar, required this.shown});

  final AccommodationAvailabilityNotifier calendar;
  final AvailabilityMonth shown;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final bool isBusy = calendar.isLoading || calendar.isWriting;

    return Row(
      children: <Widget>[
        Text(AppDates.month(calendar.month), style: text.headlineSmall),
        const SizedBox(width: AppSpacing.md),
        IconButton(
          onPressed: isBusy ? null : calendar.openPreviousMonth,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'The month before',
        ),
        IconButton(
          onPressed: isBusy ? null : calendar.openNextMonth,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'The month after',
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton(
          onPressed: isBusy || calendar.isOnThisMonth
              ? null
              : calendar.openThisMonth,
          child: const Text('This month'),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Text(
            _line,
            textAlign: TextAlign.right,
            style: text.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String get _line {
    final List<String> counted = <String>[
      if (shown.bookedNights > 0) '${shown.bookedNights} booked',
      if (shown.blockedDays > 0) '${shown.blockedDays} blocked',
      if (shown.repricedDays > 0) '${shown.repricedDays} repriced',
    ];

    return counted.isEmpty
        ? 'Every night this month is open at the listing price.'
        : 'Nights this month: ${counted.join(' · ')}';
  }
}

// The strip stands whether or not anything is chosen, so the calendar under it
// does not move a row every time a day is clicked.
class _Chosen extends StatelessWidget {
  const _Chosen({required this.calendar, required this.nightlyPrice});

  final AccommodationAvailabilityNotifier calendar;
  final double nightlyPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.footerRow,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.hover,
        borderRadius: AppRadii.medium,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _line,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (calendar.chosenEntry != null ||
              calendar.selection != null) ...<Widget>[
            TextButton(
              onPressed: calendar.isWriting ? null : calendar.clearChoice,
              child: const Text('Clear'),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (calendar.isStale)
            OutlinedButton(
              onPressed: calendar.isLoading ? null : calendar.load,
              child: const Text('Try again'),
            )
          else if (calendar.chosenEntry
              case final AccommodationAvailability entry)
            OutlinedButton(
              onPressed: calendar.isWriting
                  ? null
                  : () => _confirmRemoval(context, entry),
              child: Text(calendar.isWriting ? 'Removing' : 'Remove entry'),
            )
          else if (calendar.selection != null)
            _Adding(calendar: calendar, onWrite: () => _write(context)),
        ],
      ),
    );
  }

  String get _line {
    if (calendar.isStale) {
      return 'That change stood, but the calendar could not be read back '
          'afterwards, so what is drawn here is behind the server.';
    }

    if (calendar.chosenEntry case final AccommodationAvailability entry) {
      return AvailabilityWords.entry(entry);
    }

    if (calendar.selection case (final DateTime from, final DateTime to)) {
      final String span =
          '${AvailabilityWords.nights(calendar.selectedNights)} · '
          '${AvailabilityWords.span(from, to)}';

      return calendar.isSelectionRefused ? '$span — $refusal' : span;
    }

    return 'Click a day to write over it, and a second day for a range. '
        'A day that already carries an entry opens that entry instead.';
  }

  // The server's own refusal, said before the write rather than after it.
  static const String refusal =
      'These dates already carry an entry. Remove that one before adding this.';

  Future<void> _write(BuildContext context) async {
    if (calendar.selection case (final DateTime from, final DateTime to)) {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) => AvailabilityEntryDialog(
          from: from,
          to: to,
          nights: calendar.selectedNights,
          bookedNights: calendar.bookedNightsSelected,
          nightlyPrice: nightlyPrice,
          add: calendar.add,
        ),
      );
    }
  }

  Future<void> _confirmRemoval(
    BuildContext context,
    AccommodationAvailability entry,
  ) async {
    final bool agreed = await ConfirmationDialog.ask(
      context,
      title: 'Remove this entry?',
      message:
          '${AvailabilityWords.entry(entry)}. Those nights go back to being '
          'open at ${AppNumbers.money(nightlyPrice)} a night.',
      confirmLabel: 'Remove entry',
      isDestructive: true,
    );

    if (agreed) {
      await calendar.removeChosenEntry();
    }
  }
}

class _Adding extends StatelessWidget {
  const _Adding({required this.calendar, required this.onWrite});

  final AccommodationAvailabilityNotifier calendar;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final Widget button = FilledButton(
      onPressed: calendar.canWriteSelection ? onWrite : null,
      child: const Text('Add entry'),
    );

    return calendar.isSelectionRefused
        ? Tooltip(message: _Chosen.refusal, child: button)
        : button;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.nightlyPrice});

  final double nightlyPrice;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        const Expanded(
          child: Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _Swatch(colour: AppColors.infoGround, label: 'Repriced'),
              _Swatch(colour: AppColors.neutralGround, label: 'Blocked'),
              _Swatch(colour: AppColors.indigo, label: 'Confirmed'),
              _Swatch(colour: AppColors.warning, label: 'Held'),
              _Swatch(colour: AppColors.neutral, label: 'Finished'),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Text(
          'Otherwise ${AppNumbers.money(nightlyPrice)} a night',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.colour, required this.label});

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: AppSizes.dot,
          height: AppSizes.dot,
          decoration: BoxDecoration(
            color: colour,
            borderRadius: AppRadii.small,
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
