import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/quantity_stepper.dart';

import '../../support/widgets.dart';

void main() {
  Widget stepper(
    int value, {
    int minimum = 1,
    int maximum = 4,
    ValueChanged<int>? onChanged,
  }) => drawn(
    QuantityStepper(
      label: 'Guests',
      detail: 'This place sleeps 4.',
      value: value,
      minimum: minimum,
      maximum: maximum,
      onChanged: onChanged ?? (int _) {},
    ),
  );

  testWidgets('the value is drawn between the two steps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(stepper(2));

    expect(find.text('Guests'), findsOneWidget);
    expect(find.text('This place sleeps 4.'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a step answers with the value on the other side of it', (
    WidgetTester tester,
  ) async {
    final List<int> chosen = <int>[];

    await tester.pumpWidget(stepper(2, onChanged: chosen.add));

    await tester.tap(find.byTooltip('One more'));
    await tester.tap(find.byTooltip('One fewer'));

    expect(chosen, <int>[3, 1]);
  });

  // A step that would leave the range is not offered rather than answered and
  // then refused by whoever holds the value.
  testWidgets('neither end steps past itself', (WidgetTester tester) async {
    await tester.pumpWidget(stepper(1));
    expect(_step(tester, Icons.remove_rounded).onPressed, isNull);
    expect(_step(tester, Icons.add_rounded).onPressed, isNotNull);

    await tester.pumpWidget(stepper(4));
    expect(_step(tester, Icons.add_rounded).onPressed, isNull);
    expect(_step(tester, Icons.remove_rounded).onPressed, isNotNull);
  });
}

IconButton _step(WidgetTester tester, IconData icon) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, icon));
