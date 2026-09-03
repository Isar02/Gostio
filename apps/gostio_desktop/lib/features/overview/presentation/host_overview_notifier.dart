import '../../../core/network/api_exception.dart';
import '../../../core/state/screen_notifier.dart';
import '../../../core/time/calendar_days.dart';
import '../data/host_overview.dart';
import '../data/overview_month.dart';
import '../data/overview_repository.dart';

class HostOverviewNotifier extends ScreenNotifier {
  HostOverviewNotifier(this._overview, {required this.hostId})
    : _month = CalendarDays.firstOfMonth(CalendarDays.today());

  final OverviewRepository _overview;
  final int hostId;

  int _request = 0;
  bool _isLoading = false;
  DateTime _month;
  HostOverview? _figures;
  OverviewMonth? _calendar;
  ApiException? _failure;

  DateTime get month => _month;

  bool get isLoading => _isLoading;

  HostOverview? get figures => _figures;

  OverviewMonth? get calendar => _calendar;

  String? get failureMessage => _failure?.message;

  String? get failureTraceId => _failure?.traceId;

  bool get isOnThisMonth =>
      _month == CalendarDays.firstOfMonth(CalendarDays.today());

  Future<void> reload() => _read(figuresToo: true);

  // A month that moves drops the one that was drawn: the calendar of another
  // month is not this one with a different heading over it.
  Future<void> moveBy(int months) =>
      showMonth(CalendarDays.addMonths(_month, months));

  Future<void> showThisMonth() =>
      showMonth(CalendarDays.firstOfMonth(CalendarDays.today()));

  Future<void> showMonth(DateTime month) {
    final DateTime asked = CalendarDays.firstOfMonth(month);

    if (asked == _month) {
      return Future<void>.value();
    }

    _month = asked;
    _calendar = null;

    return _read(figuresToo: false);
  }

  Future<void> _read({required bool figuresToo}) async {
    // Taken before anything is asked for, so an answer to a month since moved
    // off cannot land on the one now drawn.
    final int request = ++_request;
    final DateTime asked = _month;

    _isLoading = true;
    _failure = null;
    publish();

    HostOverview? figures;
    OverviewMonth? calendar;
    ApiException? failure;

    try {
      final Future<HostOverview>? standing = figuresToo
          ? _overview.host(hostId)
          : null;
      final Future<OverviewMonth> month = _overview.month(
        asked,
        hostId: hostId,
      );

      await Future.wait<Object?>(<Future<Object?>>[?standing, month]);

      figures = await standing;
      calendar = await month;
    } on ApiException catch (thrown) {
      failure = thrown;
    }

    if (request != _request) {
      return;
    }

    // The figures are the host's rather than the month's, so a month that
    // failed to read leaves them where they are.
    _figures = figures ?? _figures;
    _calendar = calendar;
    _failure = failure;
    _isLoading = false;
    publish();
  }
}
