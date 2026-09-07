import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/state/foreground_poll.dart';

void main() {
  testWidgets('a poll created while paused does not start a timer', (
    WidgetTester tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    int reads = 0;
    final ForegroundPoll poll = ForegroundPoll(() async => reads++);
    addTearDown(() {
      poll.dispose();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    await tester.pump(ForegroundPoll.interval * 2);

    expect(reads, 0);
  });
}
