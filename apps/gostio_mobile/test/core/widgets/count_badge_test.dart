import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/count_badge.dart';

import '../../support/phone.dart';
import '../../support/widgets.dart';

void main() {
  setUp(usePhoneScreen);

  // Nothing to say is said with nothing rather than with a nought the reader
  // has to interpret.
  testWidgets('a count of none is not drawn', (WidgetTester tester) async {
    await tester.pumpWidget(drawn(const CountBadge(0)));

    expect(find.text('0'), findsNothing);
  });

  testWidgets('a count is drawn as it stands', (WidgetTester tester) async {
    await tester.pumpWidget(drawn(const CountBadge(7)));

    expect(find.text('7'), findsOneWidget);
  });

  // Past a point the figure stops being read and starts being measured, and a
  // badge that grows wide enough to print it covers what it sits on.
  testWidgets('a count too large to draw is capped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(drawn(const CountBadge(140)));

    expect(find.text('99+'), findsOneWidget);
  });
}
