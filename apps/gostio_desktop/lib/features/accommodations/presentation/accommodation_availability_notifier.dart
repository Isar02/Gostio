import 'package:gostio_core/gostio_core.dart';

import '../../../core/state/screen_notifier.dart';
import '../../reservations/data/reservations_repository.dart';
import '../data/accommodation_availability_repository.dart';
import '../data/availability_draft.dart';
import 'availability_month.dart';

// The month on screen and the rows it was composed from are written together,
// and only the newest read may write them: a month left behind by a quick
// second click, or one the API refused, leaves the calendar showing the month
// it was already drawing rather than a grid labelled one thing and filled with
// another. A month that could not be read back after a write is behind what
// the server holds, and its overlap guard does not know about the entry that
// has just landed, so nothing more is written from it until a read succeeds.
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
  bool _isWriting = false;
  bool _isStale = false;
  DateTime _month;
  AvailabilityMonth? _shown;
  ApiException? _failure;

  DateTime? _anchor;
  DateTime? _reach;
  bool _isSpanSettled = false;
  AccommodationAvailability? _chosenEntry;

  DateTime get month => _month;

  AvailabilityMonth? get shown => _shown;

  bool get isLoading => _isLoading;

  bool get isWriting => _isWriting;

  bool get isStale => _isStale;

  bool get isOnThisMonth =>
      _month == CalendarDays.firstOfMonth(CalendarDays.today());

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  AccommodationAvailability? get chosenEntry => _chosenEntry;

  (DateTime, DateTime)? get selection {
    final DateTime? anchor = _anchor;
    final DateTime? reach = _reach;

    if (anchor == null || reach == null) {
      return null;
    }

    return reach.isBefore(anchor) ? (reach, anchor) : (anchor, reach);
  }

  (DateTime, DateTime)? get highlight {
    if (_chosenEntry case final AccommodationAvailability entry) {
      return (entry.startDate, entry.endDate);
    }

    return selection;
  }

  bool get isSelectionRefused {
    if (selection case (final DateTime from, final DateTime to)) {
      return _shown?.hasAnEntryBetween(from: from, to: to) ?? false;
    }

    return false;
  }

  bool get canWriteSelection =>
      selection != null && !isSelectionRefused && !_isStale;

  int get selectedNights {
    if (selection case (final DateTime from, final DateTime to)) {
      return CalendarDays.daysBetween(from, to) + 1;
    }

    return 0;
  }

  int get bookedNightsSelected {
    if (selection case (final DateTime from, final DateTime to)) {
      return _shown?.bookedNightsBetween(from: from, to: to) ?? 0;
    }

    return 0;
  }

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

      // The same window asked of two endpoints that know nothing of each
      // other, so they are asked at once: a month drawn after two round trips
      // in a row waits for both of them end to end.
      final List<Object?> answers = await Future.wait(<Future<Object?>>[
        _availability.forWindow(accommodationId, from: from, to: to),
        _reservations.forAccommodationWindow(
          accommodationId,
          from: from,
          to: to,
        ),
      ]);

      composed = AvailabilityMonth.of(
        month: month,
        entries: answers[0]! as List<AccommodationAvailability>,
        bookings: answers[1]! as List<Reservation>,
        today: CalendarDays.today(),
      );
    } on ApiException catch (thrown) {
      failure = thrown;
    }

    if (read != _read) {
      return;
    }

    // What was chosen was chosen on rows that have just been replaced, so it
    // goes with them: an entry held here after a reload could be one the
    // server no longer has.
    if (composed != null) {
      _month = month;
      _shown = composed;
      _isStale = false;
      _forgetChoice();
    }

    _failure = failure;
    _isLoading = false;
    publish();
  }

  void chooseDay(AvailabilityDay day) {
    if (day.entry case final AccommodationAvailability entry) {
      _chosenEntry = entry;
      _anchor = null;
      _reach = null;
    } else if (_anchor == null || _isSpanSettled) {
      _chosenEntry = null;
      _anchor = day.date;
      _reach = day.date;
      _isSpanSettled = false;
    } else {
      _reach = day.date;
      _isSpanSettled = true;
    }

    publish();
  }

  void reachTo(AvailabilityDay day) {
    if (_anchor == null || _isSpanSettled || _reach == day.date) {
      return;
    }

    _reach = day.date;
    publish();
  }

  void clearChoice() {
    _forgetChoice();
    publish();
  }

  // A refused write is answered to the caller rather than held here: the
  // dialog that asked for it is what has to stay open and say so. A removal
  // has no dialog left by then, so that one is left on the calendar.
  Future<ApiException?> add(AvailabilityDraft draft) async {
    _isWriting = true;
    _failure = null;
    publish();

    try {
      await _availability.add(accommodationId, draft);
    } on ApiException catch (thrown) {
      _isWriting = false;
      publish();

      return thrown;
    }

    _isWriting = false;
    _isStale = true;
    await open(_month);

    return null;
  }

  Future<void> removeChosenEntry() async {
    final AccommodationAvailability? entry = _chosenEntry;
    if (entry == null) {
      return;
    }

    _isWriting = true;
    _failure = null;
    publish();

    try {
      await _availability.delete(accommodationId, entry.id);
    } on ApiException catch (thrown) {
      _failure = thrown;
      _isWriting = false;
      publish();

      return;
    }

    _isWriting = false;
    _isStale = true;
    await open(_month);
  }

  void _forgetChoice() {
    _anchor = null;
    _reach = null;
    _isSpanSettled = false;
    _chosenEntry = null;
  }
}
