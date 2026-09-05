import 'package:gostio_core/gostio_core.dart';

import '../../../core/calendar/date_range.dart';
import '../../../core/calendar/range_choice.dart';
import '../data/booking_repository.dart';
import 'booking_notifier.dart';

// A stay being taken: the nights chosen off the calendar and the party coming.
// Which nights may be chosen is the calendar's answer and is asked for on each
// gesture, because a month lands while the reader is looking at it.
class StayBookingNotifier extends BookingNotifier {
  StayBookingNotifier(this._repository, this.stay);

  final BookingRepository _repository;
  final Accommodation stay;

  RangeChoice _choice = RangeChoice(firstDay: CalendarDays.today());

  RangeChoice get choice => _choice;

  DateRange? get dates => _choice.range;

  @override
  int get maximumGuests => stay.maxGuests;

  // A first night held with no last one yet is already a choice: leaving with
  // it is leaving something the reader put there.
  @override
  bool get isChosen => _choice.from != null;

  @override
  Future<Reservation> Function()? get pending {
    final DateRange? dates = this.dates;

    return dates == null
        ? null
        : () => _repository.bookStay(
            accommodationId: stay.id,
            dates: dates,
            guestCount: guestCount,
          );
  }

  void take(DateTime day, {required bool Function(DateTime night) isNight}) {
    _choice = _choice.take(day, isNight: isNight);
    choiceChanged();
  }

  void clearDates() {
    _choice = _choice.cleared;
    choiceChanged();
  }
}
