import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/bottom_action_bar.dart';

import '../../support/widgets.dart';

void main() {
  testWidgets('the figure being agreed to stays beside the button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        BottomActionBar(
          label: '360,00 KM',
          detail: 'Three nights',
          action: FilledButton(onPressed: () {}, child: const Text('Reserve')),
        ),
      ),
    );

    expect(find.text('360,00 KM'), findsOneWidget);
    expect(find.text('Three nights'), findsOneWidget);
    expect(find.text('Reserve'), findsOneWidget);
  });

  // With nothing named beside it the button is the whole bar; a half-width
  // primary action reads as the lesser of two.
  testWidgets('an unnamed bar gives the button its whole width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        BottomActionBar(
          action: FilledButton(onPressed: () {}, child: const Text('Continue')),
        ),
      ),
    );

    final double bar = tester.getSize(find.byType(BottomActionBar)).width;
    final double button = tester.getSize(find.byType(FilledButton)).width;

    expect(button, greaterThan(bar / 2));
  });

  testWidgets('a named bar leaves the button only what it needs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        BottomActionBar(
          label: '360,00 KM',
          action: FilledButton(onPressed: () {}, child: const Text('Reserve')),
        ),
      ),
    );

    final double bar = tester.getSize(find.byType(BottomActionBar)).width;
    final double button = tester.getSize(find.byType(FilledButton)).width;

    expect(button, lessThan(bar / 2));
  });

  testWidgets('a second action sits before the first', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        BottomActionBar(
          label: '360,00 KM',
          secondary: IconButton(
            onPressed: () {},
            icon: const Icon(Icons.favorite_border),
          ),
          action: FilledButton(onPressed: () {}, child: const Text('Reserve')),
        ),
      ),
    );

    expect(
      tester.getCenter(find.byType(IconButton)).dx,
      lessThan(tester.getCenter(find.byType(FilledButton)).dx),
    );
  });
}
