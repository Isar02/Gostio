import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_desktop/core/network/api_exception.dart';
import 'package:gostio_desktop/features/overview/presentation/platform_overview_notifier.dart';

import '../../../support/overview_doubles.dart';
import '../../../support/overview_fixture.dart';

void main() {
  test('the panel is one read of the whole platform', () async {
    final OverviewDouble overview = OverviewDouble(
      standing: platformOverview(users: 1247),
    );
    final PlatformOverviewNotifier notifier = _notifier(overview);

    await notifier.reload();

    expect(overview.platformReads, 1);
    expect(notifier.standing?.users, 1247);
    expect(notifier.isLoading, isFalse);
    expect(notifier.failureMessage, isNull);
  });

  test('a refusal is said with the sentence the API sent', () async {
    final PlatformOverviewNotifier notifier = _notifier(
      OverviewDouble(
        standing: platformOverview(),
        failing: const ApiException(
          message: 'The platform could not be read.',
          traceId: 'a51b30',
        ),
      ),
    );

    await notifier.reload();

    expect(notifier.standing, isNull);
    expect(notifier.failureMessage, 'The platform could not be read.');
    expect(notifier.failureTraceId, 'a51b30');
    expect(notifier.isLoading, isFalse);
  });
}

PlatformOverviewNotifier _notifier(OverviewDouble overview) {
  final PlatformOverviewNotifier notifier = PlatformOverviewNotifier(overview);
  addTearDown(notifier.dispose);

  return notifier;
}
