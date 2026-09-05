import 'package:flutter/material.dart';
import 'package:gostio_core/gostio_core.dart';
import 'package:provider/provider.dart';

import '../../../core/calendar/stay_calendar_notifier.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/stay_month_calendar.dart';
import '../data/listing_repository.dart';

// What the listing has left, a month at a time, with what each night costs
// under it. Nothing is chosen here: this is the answer to *when could I come
// and what would it cost*, and taking a range is the booking screen's gesture.
class ListingAvailability extends StatelessWidget {
  const ListingAvailability(this.accommodationId, {super.key});

  final int accommodationId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StayCalendarNotifier>(
      create: (BuildContext context) {
        final ListingRepository listings = context.read<ListingRepository>();

        return StayCalendarNotifier(
          (DateTime from, DateTime to) =>
              listings.calendar(accommodationId, from: from, to: to),
        );
      },
      child: const _Calendar(),
    );
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar();

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
                  StayMonthCalendar(calendar: calendar),
                ],
              ),
    );
  }
}
