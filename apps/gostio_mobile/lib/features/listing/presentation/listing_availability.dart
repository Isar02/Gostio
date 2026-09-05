import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/app_notice.dart';
import '../../../core/widgets/month_grid.dart';
import '../../../core/widgets/screen_states.dart';
import '../../../core/widgets/section_header.dart';
import '../data/listing_repository.dart';
import 'stay_calendar_notifier.dart';

// What the listing has left, a month at a time, with what each night costs
// under it. Nothing is chosen here: this is the answer to *when could I come
// and what would it cost*, and taking a range is the booking screen's gesture.
class ListingAvailability extends StatelessWidget {
  const ListingAvailability(this.accommodationId, {super.key});

  final int accommodationId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StayCalendarNotifier>(
      create: (BuildContext context) => StayCalendarNotifier(
        context.read<ListingRepository>(),
        accommodationId,
      ),
      child: const _Calendar(),
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar();

  // Roughly the room a month takes, held while one is being read so that the
  // page under it does not lurch when it lands.
  //
  // The grid itself is not held to it. A month drawn as six whole weeks is
  // taller than this — the weekdays above it are a row of their own — and a box
  // that fixed the height would clip the last week of every such month.
  static const double _whileRead = AppSizes.calendarCellWithFigure * 6;

  @override
  Widget build(BuildContext context) {
    return Consumer<StayCalendarNotifier>(
      builder:
          (BuildContext context, StayCalendarNotifier calendar, Widget? _) =>
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SectionHeader(
                    'Availability',
                    subtitle:
                        'Figures are ${AppNumbers.currency} per night. '
                        'Nights already taken are struck through.',
                  ),
                  MonthBar(
                    month: calendar.month,
                    onPrevious: calendar.canGoBack
                        ? () => calendar.moveMonths(-1)
                        : null,
                    onNext: () => calendar.moveMonths(1),
                  ),
                  _month(calendar),
                ],
              ),
    );
  }

  Widget _month(StayCalendarNotifier calendar) {
    if (!calendar.hasLanded) {
      if (calendar.isLoading) {
        return const SizedBox(height: _whileRead, child: LoadingState());
      }

      if (calendar.failureMessage case final String message) {
        return SizedBox(
          height: _whileRead,
          child: Column(
            children: <Widget>[
              AppNotice(message),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: calendar.retry,
                child: const Text('Try again'),
              ),
            ],
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: MonthGrid(
        month: calendar.month,
        isTakeable: calendar.isBookable,
        isSold: calendar.isTaken,
        figureFor: (DateTime day) => _price(calendar, day),
      ),
    );
  }

  // A night nobody may book any more is not priced: the figure under a day is
  // what it would cost to take it, and a night that is gone costs nothing.
  String? _price(StayCalendarNotifier calendar, DateTime day) {
    if (!calendar.isBookable(day)) {
      return null;
    }

    final StayCalendarDay? night = calendar.dayOf(day);

    return night == null ? null : AppNumbers.typed(night.price);
  }
}
