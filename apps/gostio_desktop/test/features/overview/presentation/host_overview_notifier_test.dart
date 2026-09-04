import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/core/time/calendar_days.dart';
import 'package:gostio_desktop/features/overview/presentation/host_overview_notifier.dart';

import '../../../support/overview_doubles.dart';
import '../../../support/overview_fixture.dart';

void main() {
  test('the panel opens on the month the clock is in', () async {
    final OverviewDouble overview = OverviewDouble(
      figures: hostOverview(accommodations: 4),
    );
    final HostOverviewNotifier notifier = _notifier(overview);

    await notifier.reload();

    expect(notifier.month, CalendarDays.firstOfMonth(CalendarDays.today()));
    expect(notifier.isOnThisMonth, isTrue);
    expect(notifier.figures?.accommodations, 4);
    expect(notifier.calendar, isNotNull);
    expect(overview.hosts, <int>[7]);
    expect(overview.months, <DateTime>[notifier.month]);
  });

  // The figures are the host's rather than the month's, so a month that moves
  // is a second read of the calendar alone.
  test('a month that moves reads the calendar and not the figures', () async {
    final OverviewDouble overview = OverviewDouble();
    final HostOverviewNotifier notifier = _notifier(overview);

    await notifier.reload();
    await notifier.moveBy(1);

    expect(overview.hosts, hasLength(1));
    expect(overview.months, hasLength(2));
    expect(
      notifier.month,
      CalendarDays.addMonths(
        CalendarDays.firstOfMonth(CalendarDays.today()),
        1,
      ),
    );
    expect(notifier.isOnThisMonth, isFalse);
    expect(notifier.figures, isNotNull);
  });

  test('the month asked for is the month drawn', () async {
    final OverviewDouble overview = OverviewDouble();
    final HostOverviewNotifier notifier = _notifier(overview);

    await notifier.reload();
    await notifier.moveBy(-2);

    expect(notifier.calendar?.month, notifier.month);
    expect(overview.months.last, notifier.month);
  });

  test('the month in force is not read a second time', () async {
    final OverviewDouble overview = OverviewDouble();
    final HostOverviewNotifier notifier = _notifier(overview);

    await notifier.reload();
    await notifier.showThisMonth();

    expect(overview.months, hasLength(1));
  });

  // An answer for a month since moved off would otherwise be drawn under the
  // heading of the month now shown.
  test('an answer for a month moved off does not land', () async {
    final OverviewDouble overview = OverviewDouble(holds: true);
    final HostOverviewNotifier notifier = _notifier(overview);
    final DateTime opened = notifier.month;

    final Future<void> first = notifier.reload();
    final Future<void> second = notifier.moveBy(3);

    for (final Completer<void> wait in overview.waits.reversed) {
      wait.complete();
    }
    await Future.wait<void>(<Future<void>>[first, second]);

    expect(notifier.month, CalendarDays.addMonths(opened, 3));
    expect(notifier.calendar?.month, notifier.month);
  });

  test('a refusal is said with the sentence the API sent', () async {
    final HostOverviewNotifier notifier = _notifier(
      OverviewDouble(
        failing: const ApiException(
          message: 'The month could not be read.',
          traceId: 'd90a17',
        ),
      ),
    );

    await notifier.reload();

    expect(notifier.failureMessage, 'The month could not be read.');
    expect(notifier.failureTraceId, 'd90a17');
    expect(notifier.calendar, isNull);
    expect(notifier.isLoading, isFalse);
  });
}

HostOverviewNotifier _notifier(OverviewDouble overview) {
  final HostOverviewNotifier notifier = HostOverviewNotifier(
    overview,
    hostId: 7,
  );
  addTearDown(notifier.dispose);

  return notifier;
}
