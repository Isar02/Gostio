import '../../../core/network/api_exception.dart';
import '../../../core/state/screen_notifier.dart';
import '../../../core/time/calendar_days.dart';
import '../../reservations/data/reservation.dart';
import '../../reservations/data/reservations_repository.dart';
import '../data/accommodation_availability.dart';
import '../data/accommodation_availability_repository.dart';
import 'availability_month.dart';

// The month on screen and the rows it was composed from are written together,
// and only the newest read may write them: a month left behind by a quick
// second click, or one the API refused, leaves the calendar showing the month
// it was already drawing rather than a grid labelled one thing and filled with
// another.
class AccommodationAvailabilityNotifier extends ScreenNotifier {
  AccommodationAvailabilityNotifier(
    this._availability,
    this._reservations, {
    required this.accommodationId,
  }) : _month = CalendarDays.firstOfMonth(CalendarDays.today());

  final AccommodationAvailabilityRepository _availability;
  final ReservationsRepository _reservations;

  final int accommodationId;

  int _read = 0;
  bool _isLoading = true;
  DateTime _month;
  AvailabilityMonth? _shown;
  ApiException? _failure;

  DateTime get month => _month;

  AvailabilityMonth? get shown => _shown;

  bool get isLoading => _isLoading;

  bool get isOnThisMonth =>
      _month == CalendarDays.firstOfMonth(CalendarDays.today());

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  Future<void> load() => open(_month);

  Future<void> openNextMonth() => open(CalendarDays.addMonths(_month, 1));

  Future<void> openPreviousMonth() => open(CalendarDays.addMonths(_month, -1));

  Future<void> openThisMonth() =>
      open(CalendarDays.firstOfMonth(CalendarDays.today()));

  Future<void> open(DateTime month) async {
    final int read = ++_read;

    _isLoading = true;
    _failure = null;
    publish();

    AvailabilityMonth? composed;
    ApiException? failure;

    try {
      final DateTime from = AvailabilityMonth.startOfGrid(month);
      final DateTime to = AvailabilityMonth.endOfGrid(month);

      final List<AccommodationAvailability> entries = await _availability
          .forWindow(accommodationId, from: from, to: to);
      final List<Reservation> bookings = await _reservations
          .forAccommodationWindow(accommodationId, from: from, to: to);

      composed = AvailabilityMonth.of(
        month: month,
        entries: entries,
        bookings: bookings,
        today: CalendarDays.today(),
      );
    } on ApiException catch (thrown) {
      failure = thrown;
    }

    if (read != _read) {
      return;
    }

    if (composed != null) {
      _month = month;
      _shown = composed;
    }

    _failure = failure;
    _isLoading = false;
    publish();
  }
}
