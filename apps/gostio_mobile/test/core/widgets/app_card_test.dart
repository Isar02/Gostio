import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gostio_mobile/core/widgets/app_card.dart';

import '../../support/widgets.dart';

void main() {
  testWidgets('a card without a gesture answers a tap with nothing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(drawn(const AppCard(child: Text('Kravice falls'))));

    await tester.tap(find.text('Kravice falls'));
    await tester.pump();

    expect(find.text('Kravice falls'), findsOneWidget);
  });

  testWidgets('a card opens what it stands for', (WidgetTester tester) async {
    int opened = 0;

    await tester.pumpWidget(
      drawn(
        AppCard(
          onTap: () => opened++,
          child: const Text('Stone villa on the hill above Neum'),
        ),
      ),
    );

    await tester.tap(find.byType(AppCard));
    await tester.pump();

    expect(opened, 1);
  });

  // The selected border is what a chosen card is told apart by, so it may not
  // be the same hairline every other card carries.
  testWidgets('a selected card is drawn differently from an unselected one', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      drawn(
        const Column(
          children: <Widget>[
            AppCard(isSelected: true, child: Text('Chosen')),
            AppCard(child: Text('Not chosen')),
          ],
        ),
      ),
    );

    final List<ShapeBorder?> shapes = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(AppCard),
            matching: find.byType(Material),
          ),
        )
        .map((Material material) => material.shape)
        .toList(growable: false);

    expect(shapes.first, isNot(shapes.last));
  });

  testWidgets('a card carries the label a reader is read it by', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      drawn(
        AppCard(
          semanticLabel: 'Cottage by the Pliva lakes, 120,00 KM per night',
          onTap: () {},
          child: const Text('Cottage by the Pliva lakes'),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel('Cottage by the Pliva lakes, 120,00 KM per night'),
      findsOneWidget,
    );

    semantics.dispose();
  });
}
